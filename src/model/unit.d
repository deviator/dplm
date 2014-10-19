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
    Tuple!( vec3, "min", vec3, "max" ) flim;

    float CxS;
    float mass;

    Tuple!( float, "dst", float, "vel" ) ready;
    float min_move;

    vec3[4] apid;

    Tuple!(float,"fov",
           float,"min",
           float,"max",
           ivec2,"size",
           float,"rate") cam;

    @property float camRatio() const
    { return cast(float)( cam.size.x ) / cam.size.y; }

    float maxResultDist( float cell ) const
    {
        auto maxAngleResolution = (cam.fov / 180 * PI) / cam.size.y;
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
    vec3 last_snapshot_pos;
    vec3 look_pnt;

    vec3[] dangers;
    vec3[] ldpoints;

    APID!vec3 pos_APID;

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

        pos_APID = new APID!vec3( prms.apid[0], prms.apid[1],
                                  prms.apid[2], prms.apid[3] );

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

        void lookPnt( in vec3 lp ) { look_pnt = lp; }
        vec3 lookPnt() const { return look_pnt; }

        Camera camera()
        {
            updateCamera();
            return cam;
        }

        bool nearTarget() const
        {
            return (target - pos).len2 < pow( params.ready.dst, 2 ) &&
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

    void appendDanger( in vec3 d ) { dangers ~= d; }

    @property vec3[] lastSnapshot() { return ldpoints; }

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

        ldpoints.length = 0;
        auto pr_inv = cam.projection.matrix.inv;
        auto tr_inv = matrix * cam.transform.matrix;

        auto mrd = params.maxResultDist( minCellSize );

        foreach( iy; 0 .. ih )
            foreach( ix; 0 .. iw )
            {
                auto val = img.pixel!float(ix,iy);

                if( val > 1-1e-6 || val < 1e-6 ) continue;

                auto fx = (ix+0.5f) / iw * 2 - 1;
                auto fy = (iy+0.5f) / ih * 2 - 1;

                auto b = project( pr_inv, vec3(fx,fy,val) );

                b *= getCorrect( b.z );
                if( abs(b.z) > mrd ) continue;

                b = project( tr_inv, b );

                auto p = b;
                ldpoints ~= p;
            }
    }

    @property float minCellSize() const
    { return reduce!min(wmap.cellSize.data.dup); }

    void updateMap()
    {
        wmap.setPoints( pos, ldpoints );
    }

    vec3 project( in mat4 m, in vec3 v )
    {
        auto buf = m * vec4(v,1.0f);
        return buf.xyz / buf.w;
    }

    float getCorrect( float val_z )
    {
        auto p = abs( val_z / cam.far );
        return 1 - getDepthRelativeError( p ) / p;
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

    vec3 drag( in vec3 v, float rho )
    { return -v * v.len * params.CxS * rho / 2.0f; }

    vec3 controlForce( float dt )
    {
        vec3 res;
        res += pos_APID( target - pos, dt );
        res += processDanger() * vec3(800);

        return limited( res, params.flim.max,
                             params.flim.min );
    }

    vec3 processDanger()
    {
        if( dangers.length == 0 )
            return vec3(0);

        vec3 ret;
        foreach( d; dangers )
        {
            auto dst = pos - d;
            ret += dst.e / ( dst.len2 + 0.1 );
        }
        ret /= dangers.length;
        dangers.length = 0;
        return ret;
    }

    void timer( float dt )
    {
        snapshot_timer += dt;
    }

    void updateCamera()
    {
        cam.target = (matrix.inv * vec4(lookTarget,1)).xyz;
    }

    @property vec3 lookTarget() const
    {
        if( (pos - target).len2 < pow(params.min_move,2) )
            return look_pnt;
        else return target;
    }
}
