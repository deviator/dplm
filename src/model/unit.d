module model.unit;

import std.math;
import std.typecons;
import std.algorithm;

import des.math.linear;
import des.math.basic;

import des.il;

import model.pid;
import model.util;
import model.worldmap;

import std.stdio;

struct PhVec
{
    vec3 pos, vel;
    quat rot = quat(0,0,0,1);

    mixin( BasicMathOp!"pos vel rot" );
}

struct UnitParams
{
    float gflim;
    float vfmin;
    float vfmax;

    float CxS;
    float mass;

    Tuple!( float, "dst", float, "vel" ) ready;
    float min_move;

    vec3[3] pid;

    Tuple!(float,"fov",
           float,"min",
           float,"max",
           ivec2,"size",
           float,"rate") cam;

    @property float camRatio() const
    { return cast(float)( cam.size.x ) / cam.size.y; }

    float maxResultDist( float cell ) const
    {
        auto maxAngleResolution = (cam.fov / 180.0f * PI) / cam.size.y;
        return abs( cell / tan(maxAngleResolution) );
    }
}

class Unit : Node
{
protected:

    PhVec phcrd;
    UnitParams params;

    float snapshot_timer = 0;

    vec3 trg_pos;

    vec3 way_point;

    vec3 last_snapshot_pos;
    vec3 look_pnt;

    fSeg[] dangers;
    vec4[] ldpoints;

    PID!vec3 pos_PID;

    SimpleCamera cam;

    WorldMap wmap;
    bool ready_to_snapshot = true;

public:

    this( PhVec initial, UnitParams prms, WorldMap worldmap )
    in{ assert( worldmap !is null ); } body
    {
        phcrd = initial;
        params = prms;

        trg_pos = initial.pos;

        pos_PID = new PID!vec3( prms.pid[0], prms.pid[1], prms.pid[2] );

        wmap = worldmap;

        cam = new SimpleCamera(this);
        prepareCamera();
    }

    @property
    {
        const
        {
            vec3 pos() { return phcrd.pos; }
            vec3 vel() { return phcrd.vel; }
            quat rot() { return phcrd.rot; }

            /+ interface Node +/
            mat4 matrix() { return quatAndPosToMatrix( phcrd.rot, phcrd.pos ); }
            const(Node) parent() { return null; }
            /+ --//-- +/
        }
        
        void target( in vec3 tp )
        {
            trg_pos = tp;
            ready_to_snapshot = true;
        }

        vec3 target() const { return trg_pos; }
        vec3 wayPoint() const { return way_point; }

        void lookPnt( in vec3 lp ) { look_pnt = lp; }
        vec3 lookPnt() const { return look_pnt; }

        Camera camera()
        {
            updateCamera();
            return cam;
        }

        bool nearTarget() const
        {
            return (wayPoint - pos).len2 < pow( params.ready.dst, 2 ) &&
                vel.len2 < pow( params.ready.vel, 2 );
        }

        bool readyToSnapshot() const
        { return snapshotTimeout && hasMinMoveFromLastSnapshot; }

        bool snapshotTimeout() const
        { return snapshot_timer > 1.0f / params.cam.rate; }

        bool hasMinMoveFromLastSnapshot() const
        { return (last_snapshot_pos - pos).len2 > pow( params.min_move, 2 ); }

        ivec2 snapshotResolution() const
        { return params.cam.size; }
    }

    void step( float t, float dt )
    {
        phcrd += rpart( t, dt ) * dt;
        timer( dt );
    }

    void appendDanger( in fSeg[] d... ) { dangers ~= d; }

    @property vec4[] lastSnapshot() { return ldpoints; }

    @property vec4[] lastWall()
    {
        vec4[] ret;
        foreach( w; wall ) ret ~= vec4( w, 1 );
        return ret;
    }

    void addSnapshot( in Image!2 img )
    {
        snapshot_timer = 0;
        last_snapshot_pos = pos;
        updatePoints( img );
        updateMap();
    }

protected:

    void prepareCamera()
    {
        cam.fov   = params.cam.fov;
        cam.ratio = params.camRatio;
        cam.near  = params.cam.min;
        cam.far   = params.cam.max;
    }

    void updatePoints( in Image!2 img )
    {
        auto ih = img.size.h;
        auto iw = img.size.w;

        ldpoints.length = ih*iw;

        auto pr_inv = cam.projection.matrix.inv;
        auto tr_inv = matrix * cam.transform.matrix;

        auto mrd = params.maxResultDist( minCellSize );

        foreach( iy; 0 .. ih )
            foreach( ix; 0 .. iw )
            {
                auto val = img.pixel!float(ix,iy);

                auto fx = (ix+0.5f) / iw * 2 - 1;
                auto fy = (iy+0.5f) / ih * 2 - 1;

                auto b = project( pr_inv, vec3(fx,fy,val) );

                float fp = val < 1-1e-6 ? 1.0f : 0.0f;
                b *= getCorrect( b.z );

                version(clipbycamres)
                {
                    if( abs(b.z) > mrd )
                    {
                        fp = 0;
                        b *= mrd / abs(b.z);
                    }
                }

                b = project( tr_inv, b );

                auto p = b;
                ldpoints ~= vec4( p, fp );
            }
    }

    @property float minCellSize() const
    { return reduce!min(wmap.cellSize.data.dup); }

    void updateMap() { wmap.setPoints( pos, ldpoints ); }

    static vec3 project( in mat4 m, in vec3 v )
    {
        auto buf = m * vec4( v, 1.0f );
        return buf.xyz / buf.w;
    }

    float getCorrect( float val_z ) const
    {
        auto p = abs( val_z / cam.far );
        return 1 - getDepthRelativeError(p);
    }

    PhVec rpart( float t, float dt )
    {
        auto f = drag( vel, 1 ) + controlForce( dt );
        auto a = f / params.mass + vec3(0,0,-9.81);

        PhVec ret;
        ret.pos = phcrd.vel;
        ret.vel = a;
        ret.rot = quat(0);

        return ret;
    }

    vec3 drag( in vec3 v, float rho ) const
    { return -v * v.len * params.CxS * rho / 2.0f; }

    vec3 controlForce( float dt )
    {
        updateLocalTarget();
        auto res = logicCorrect( pos_PID( limitedForce(wayPoint-pos), dt ) );
        return limitedForce( res + vec3(0,0,9.81*params.mass) );
    }

    vec3 limitedForce( vec3 ff )
    {
        if( ff.xy.len > params.gflim )
            ff = vec3( ff.xy.e * params.gflim, ff.z );
        if( ff.z > params.vfmax ) ff.z = params.vfmax;
        if( ff.z < params.vfmin ) ff.z = params.vfmin;
        return ff;
    }

    vec3 logicCorrect( vec3 trgf )
    {
        
        auto ff = limitedForce( trgf );
        auto pd = limitedForce( processDanger() );
        auto cc = vec3(0,0,0);
        if( pos.z < 1 ) cc.z = params.vfmax;
        return ff + pd + cc;
        //auto res = ff + pd + cc;
        //auto cr = processMap( res );
        //if( cr.len2 == 0 ) return res;
        //return cr.e * res.len;
    }

    vec3 processDanger()
    {
        if( dangers.length == 0 ) return vec3(0);

        auto crs = fSeg( pos, vel );
        vec3 corr;
        foreach( d; dangers )
        {
            auto dst = pos - d.pnt;
            corr += dst.e / ( dst.len2 + 0.1 );

            if( d.dir.len2 > 0 )
            {
                auto vdst = crs.altitude(d);
                auto pp = vdst.pnt - pos;

                corr += -vdst.dir.e * vel.len / ( pp.len2 + 0.1 );
            }
        }
        corr /= dangers.length;
        dangers.length = 0;

        return corr;
    }

    void updateLocalTarget()
    {
        auto nv = wmap.nearestVolume(pos);

        // сначала двигаемся к карте
        if( nv.len2 > 0.001 )
        {
            way_point = pos + nv;
            return;
        }

        way_point = trg_pos;
    }

    vec3[] wall;

    vec3 processMap( vec3 dir )
    {
        if( dir.len2 == 0 ) return dir;

        float max_dst = 10;
        float dang_rad = max_dst / 2;

        auto trg = pos + dir.e * max_dst * max_dst;

        updateWallAndCalcNear( trg, max_dst );

        if( !wall.length ) return trg - pos;

        auto wall_c = mean( wall );
        float max_wall_dst = reduce!max( dang_rad, map!(a=>(wall_c-a).len)( wall ) );

        //auto ntrg = calcSphericBypass( pos, trg, wall_c, max_wall_dst + dang_rad );
        //return ntrg - pos;

        return calcWallRepulsion( dir, dang_rad );
    }

    vec3 calcWallRepulsion( vec3 dir, float dist )
    {
        vec3 rp;
        size_t k = 0;
        foreach( w; wall )
        {
            auto dst = pos - w;
            if( dst.len < dist )
            {
                rp += dst.e * ( dist - dst.len );
                k++;
            }
        }
        if( k == 0 ) return dir;
        return rp / k;
    }

    vec3 updateWallAndCalcNear( vec3 trg, float max_dst )
    {
        float dang_dst = max_dst / 2;

        auto mpts = ldpoints ~ wmap.getFillPoints( pos, max_dst );

        trg = calcNear( mpts, trg, dang_dst );

        wall.length = 0;
        appendWall( mpts, trg, dang_dst );
        appendWall( mpts, pos, dang_dst );

        return trg;
    }

    vec3 calcNear( in vec4[] mpts, vec3 trg, float dist )
    {
        foreach( ep; mpts )
        {
            auto way = fSeg.fromPoints( pos, trg );

            auto val = ep.w;
            auto p = ep.xyz;

            if( val > 0 || val is float.nan )
            {
                auto alt = way.altitude(p);
                if( alt.dir.len < dist && (alt.pnt-pos).len <= way.dir.len )
                    trg = alt.pnt;
            }
        }
        return trg;
    }

    void appendWall( in vec4[] mpts, vec3 trg, float dist )
    {
        foreach( ep; mpts )
        {
            auto val = ep.w;
            auto p = ep.xyz;

            if( ( val > 0 || val is float.nan ) && (trg-p).len <= dist )
                wall ~= p;
        }
    }

    vec3 calcSphericBypass( vec3 from, vec3 to, vec3 center, float R )
    {
        auto way = fSeg.fromPoints( from, to );
        auto rd = center - from;
        auto A = rd.len;
        auto rde = rd / A;

        if( way.altitude(center).dir.len > R ) return to;
        if( A < R ) return from - rde * (R - A);

        auto rv = cross( rde, -way.altitude(center).dir.e ).e;
        if( !rv ) rv = cross( rde, vec3(0,0,1) ).e;

        auto up = cross( rv, rde ).e;

        auto kx = -rde * R * R/A;
        auto ky = up * R * sin( acos(R/A) );

        return from + (center + kx + ky);
    }

    static auto mean( in vec3[] arr )
    { return (reduce!((r,a)=>r+=a)(arr)) / arr.length; }

    void timer( float dt ) { snapshot_timer += dt; }

    void updateCamera()
    { cam.target = (matrix.inv * vec4(lookTarget,1)).xyz; }

    @property vec3 lookTarget() const
    {
        if( (pos - wayPoint).len2 < pow(params.min_move,2) )
            return look_pnt;
        else return (pos + vel + wayPoint) * 0.5;
    }
}
