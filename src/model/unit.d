module model.unit;

import std.math;
import std.typecons;

import des.math.linear;
import des.math.basic;

import des.il;

import model.pid;
import model.util;

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

    vec3[4] apid;

    Tuple!(float,"fov",
           float,"min",
           float,"max",
           ivec2,"size",
           float,"rate") cam;

    @property float cam_ratio() const
    { return cast(float)( cam.size.x ) / cam.size.y; }
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
    vec3[] ldpoints;

    APID!vec3 pos_APID;

    SimpleCamera cam;

public:

    this( PhVec initial, UnitParams prms )
    {
        phcrd = initial;
        params = prms;

        trg_pos = initial.pos;

        pos_APID = new APID!vec3( prms.apid[0], prms.apid[1],
                                  prms.apid[2], prms.apid[3] );

        cam = new SimpleCamera;

        cam.fov = prms.cam.fov;
        cam.ratio = prms.cam_ratio;
        cam.near = prms.cam.min;
        cam.far = prms.cam.max;
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
        { return snapshot_timer > 1.0f / params.cam.rate; }

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

        auto ih = img.size.h;
        auto iw = img.size.w;

        ldpoints.length = 0;
        //ldpoints.length = iw * ih;
        auto m = cam.projection.matrix.inv;

        foreach( iy; 0 .. ih )
            foreach( ix; 0 .. iw )
            {
                auto val = img.pixel!float(ix,iy);

                if( val > 1-1e-6 || val < 1e-6 ) continue;

                auto ind = iy * iw + ix;

                auto fx = (ix+0.5f) / iw * 2 - 1;
                auto fy = (iy+0.5f) / ih * 2 - 1;

                auto b = project( m, vec3(fx,fy,val) );

                b *= getCorrect( b.z );

                auto p = vec3( -b.z, -b.x, b.y );
                ldpoints ~= [ pos, p ];
                //ldpoints[ind] = p;
            }
    }

protected:

    float getCorrect( float val_z )
    {
        auto p = abs( val_z / cam.far );
        return 1 - getDepthRelativeError( p ) / p;
    }

    vec3 project( in mat4 m, in vec3 v )
    {
        auto buf = m * vec4(v,1.0f);
        return buf.xyz / buf.w;
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
        cam.pos = pos;
        cam.target = pos + vec3(1,0,0);
        //cam.target = look_pnt;
    }
}
