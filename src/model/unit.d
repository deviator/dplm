module model.unit;

import std.math;
import std.typecons;

import des.math.linear;
import des.math.basic;

import des.il;

import model.pid;

import std.stdio;

struct PhVec
{
    vec3 pos, vel;
    quat rot = quat(0,0,0,1);

    mixin( BasicMathOp!"pos vel rot" );
}

struct UnitParams
{
    vec3 force_lim_max, force_lim_min;

    float CxS = 0.1;
    float mass = 2;

    auto ready = Tuple!( float, "dst", float, "vel" )( 0.05, 0.01 );

    float snapshot_pause = 2;
    ivec2 snapshot_size = ivec2(64,64);

    this( vec2 hsfl, float force_z_lim_min, float force_z_lim_max,
          float cxs=0.1, float m=2,
          float ready_dst = 0.05, float ready_vel = 0.01,
          float sh_pause = 2, ivec2 sh_size = ivec2(8,8) )
    {
        force_lim_max = vec3(  hsfl, force_z_lim_max );
        force_lim_min = vec3( -hsfl, force_z_lim_min );
        CxS = cxs;
        mass = m;
        ready.dst = ready_dst;
        ready.vel = ready_vel;
        snapshot_pause = sh_pause;
        snapshot_size = sh_size;
    }
}

class Unit
{
protected:

    PhVec phcrd;
    UnitParams params;

    float snapshot_timer = 0;

    vec3 trg_pos;
    vec3 look_pnt;

    vec3[] dangers;

    APID!vec3 pos_APID;

    SimpleCamera cam;

public:

    this( PhVec initial, UnitParams prms )
    {
        phcrd = initial;
        params = prms;

        trg_pos = initial.pos;

        pos_APID = new APID!vec3( vec3(0,0,params.mass*9.81),
                                  vec3(3), vec3(0), vec3(3) );

        cam = new SimpleCamera;
        cam.fov = 90;
        cam.ratio = 1;
        cam.near = 1;
        cam.far = 100;
    }

    @property
    {
        vec3 pos() const { return phcrd.pos; }
        vec3 vel() const { return phcrd.vel; }
        quat rot() const { return phcrd.rot; }
        
        void target( in vec3 tp ) { trg_pos = tp; }
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
        { return snapshot_timer > params.snapshot_pause; }

        ivec2 snapshotResolution() const
        { return params.snapshot_size; }
    }


    void step( float t, float dt )
    {
        phcrd += rpart( t, dt ) * dt;
        timer( dt );
    }

    void appendDanger( in vec3 d ) { dangers ~= d; }


    void addSnapshot( in Image!2 img )
    {
        snapshot_timer = 0;

        /+
        foreach( y; 0 .. params.snapshot_size.y )
        {
            foreach( x; 0 .. params.snapshot_size.x )
                writef( " % 4.2f", pow( img.pixel!float(x,y), 4 ) );
            writeln();
        }
        +/
    }

protected:

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

        return limited( res, params.force_lim_max,
                             params.force_lim_min );
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
        cam.pos = pos;
        cam.target = pos + vec3(1,0,0);
        //cam.target = look_pnt;
    }
}

auto limited(T)( in T val, in T lmax, in T lmin )
    if( isVector!T )
{
    T ret = val;
    assert( ret.length == lmax.length );
    assert( ret.length == lmin.length );
    foreach( i; 0 .. ret.length )
    {
        if( ret[i] > lmax[i] ) ret[i] = lmax[i];
        if( ret[i] < lmin[i] ) ret[i] = lmin[i];
    }
    return ret;
}
