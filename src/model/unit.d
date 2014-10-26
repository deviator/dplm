module model.unit;

import std.math;
import std.range;
import std.typecons;
import std.algorithm;

import des.math.linear;
import des.math.basic;
import des.util.logger;

import des.il;

import model.pid;
import model.util;
import model.dataaccess;

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
           ivec2,"res",
           float,"rate") cam;

    @property float camRatio() const
    { return cast(float)( cam.res.x ) / cam.res.y; }

    float maxResultDist( float cell ) const
    {
        auto maxAngleResolution = (cam.fov / 180.0f * PI) / cam.res.y;
        return abs( cell / tan(maxAngleResolution) );
    }
}

class Unit : Node
{
protected:

    static size_t unit_count = 0;
    size_t id;

    PhVec phcrd;
    UnitParams params;

    float snapshot_timer = 0;

    vec3 trg_pos;

    vec3 way_point;

    vec3 last_snapshot_pos;
    vec3 look_pnt;

    fSeg[] dangers;
    vec4[] ldpoints;

    vec3[] track;
    float min_track_dist = 0.2;
    size_t max_track_cnt = 4096;

    PID!vec3 pos_PID;

    SimpleCamera cam;

    UnitDataAccess data;
    bool ready_to_snapshot = true;

public:

    this( PhVec initial, UnitParams prms, UnitDataAccess uda )
    in{ assert( uda !is null ); } body
    {
        id = unit_count++;

        phcrd = initial;
        params = prms;

        trg_pos = initial.pos;

        pos_PID = new PID!vec3( prms.pid[0], prms.pid[1], prms.pid[2] );

        data = uda;

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

        uivec2 snapshotResolution() const
        { return uivec2( params.cam.res ); }
    }

    void step( float t, float dt )
    {
        calcWayPoint();
        phcrd += rpart( t, dt ) * dt;
        timer( dt );
        trackAppend();
    }

    void appendDanger( in fSeg[] d... ) { dangers ~= d; }

    @property vec3[] currentTrack() { return track; }

    @property vec4[] lastSnapshot() { return ldpoints; }

    void addSnapshot( in Image!2 img )
    {
        snapshot_timer = 0;
        last_snapshot_pos = pos;

        data.updateMap( id, cam.projection.matrix,
                cam.far, matrix * cam.transform.matrix, img.mapAs!float );
    }

protected:

    void trackAppend()
    {
        if( track.length && (track[$-1] - pos).len2 < pow(min_track_dist,2) ) return;

        if( track.length >= max_track_cnt )
            track = track[1..$] ~ pos;
        else track ~= pos;
    }

    void prepareCamera()
    {
        cam.fov   = params.cam.fov;
        cam.ratio = params.camRatio;
        cam.near  = params.cam.min;
        cam.far   = params.cam.max;
    }

    PhVec rpart( float t, float dt )
    {
        auto f = drag(vel,1) + controlForce(dt);
        auto a = f / params.mass + vec3(0,0,-9.81);

        PhVec ret;
        ret.pos = vel;
        ret.vel = a;
        ret.rot = quat(0);

        return ret;
    }

    vec3 drag( in vec3 v, float rho ) const
    { return -v * v.len * params.CxS * rho / 2.0f; }

    vec3 controlForce( float dt )
    {
        auto flist =
            [
                limitedForce( pos_PID( wayPoint-pos, dt ) ),
                nearCorrect(),
            ];
        auto res = reduce!((r,a)=>(r+=a))( flist );
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

    vec3 nearCorrect()
    {
        float max_dst = 4.8;
        float max_dst2 = pow( max_dst, 2 );
        auto mpts = data.getPoints( pos, max_dst );

        return reduce!((r,pnt)
                {
                    auto d = pnt - pos;
                    auto dl = d.len;
                    auto ve = vel.e;
                    auto de = d.e;
                    auto pv = dot(de,ve);
                    auto nk = cross( cross( de, ve ), de );
                    if( !nk ) nk = vec3(0);
                    return r += ( -de * pow(max_dst-dl,2) * 2 + nk ) * max(0.001,pv) * 4;
                    //return r += ( -de * pow(max_dst-dl,2) * 2 * max(0,pv) + nk * max(0.1,pv) ) * 4;
                })( vec3(0,0,0), filter!(a=>(a-pos).len2 < max_dst2)(
                        chain( map!(a=>a.xyz)(filter!(a=>!(a.w<0.5))(mpts)),
                               map!(a=>a.pnt)(dangers) ) ) );
    }

    void calcWayPoint()
    {
        auto nv = data.nearestVolume(pos);

        // сначала двигаемся к карте
        if( nv.len2 > 0.001 )
        {
            way_point = pos + nv;
            return;
        }

        way_point = trg_pos;
    }

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
