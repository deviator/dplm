module model.unit;

import std.math;
import std.range;
import std.typecons;
import std.algorithm;

import des.math.linear;
import des.math.basic;
import des.space;

import des.il;

import des.util.arch;

import model.pid;
import model.camera;

import std.stdio;

/// phase vector (has basic math op)
struct UnitState
{
    vec3 pos, vel; ///
    mixin( BasicMathOp!"pos vel" );
}

///
struct UnitParams
{
    float hflim; /// horisontal force limit
    float vfmin; /// vertical minimal force
    float vfmax; /// vertical maximum force

    float CxS; /// for drag force
    float mass;

    UnitCameraParams cam; ///
}

/++ base unit class
for set/get lookAt point use `camera.target`
 +/
class BaseUnit : DesObject, SpaceNode
{
    mixin DES;
    mixin SpaceNodeHelper;

protected:

    UnitState ph;
    UnitParams prms;
    UnitCamera cam;

public:

    ///
    this( in UnitState initial, in UnitParams prms )
    {
        ph = initial;
        this.prms = prms;

        cam = new UnitCamera( this, prms.cam );
    }

    @property
    {
        ///
        UnitState state() const { return ph; }
        ///
        UnitParams params() const { return prms; }

        ///
        UnitCamera camera() { return cam; }
    }

    ///
    final void process( float t, float dt )
    {
        logic( t, dt );
        ph += rpart( t, dt ) * dt;
        self_mtr.setCol( 3, vec4(ph.pos,1) );
        postProc();
    }

protected:

    ///
    abstract void logic( float t, float dt );

    /// calc control force 
    abstract vec3 controlForce( float t, float dt );

    final UnitState rpart( float t, float dt )
    {
        auto f = dragForce() + limitedForce( controlForce( t, dt ) );

        UnitState ret;
        ret.pos = state.vel;
        ret.vel = f / params.mass + vec3(0,0,-9.81);

        return ret;
    }

    final vec3 dragForce()
    {
        enum rho = 1.0f;
        return -state.vel * state.vel.len * params.CxS * rho / 2.0f;
    }

    vec3 limitedForce( vec3 ff )
    {
        if( ff.xy.len > params.hflim )
            ff = vec3( ff.xy.e * params.hflim, ff.z );
        if( ff.z > params.vfmax ) ff.z = params.vfmax;
        if( ff.z < params.vfmin ) ff.z = params.vfmin;
        return ff;
    }

    /// post proc actions
    void postProc() {}
}

///
struct UnitTrace
{
    vec3[] data; ///

    float min_dist = 0.2; ///
    size_t max_count = 4096; ///

    ///
    this( float md, size_t mc )
    {
        min_dist = md;
        max_count = mc;
    }

    ///
    void append( in vec3 p )
    {
        if( data.length != 0 && (data[$-1] - p).len2 < min_dist * min_dist ) return;

        if( data.length < max_count ) data ~= p;
        else data = data[1..$] ~ p;
    }

    ///
    void reset() { data.length = 0; }
}

class Unit : BaseUnit
{
protected:

    vec3 trg_point;
    vec3 way_point;

    fRay[] near;

    UnitTrace hist;

    PID!vec3 pid;

public:

    this( UnitState initial, UnitParams prms, vec3[3] pp )
    {
        super( initial, prms );
        trg_point = initial.pos;
        pid = new PID!vec3( pp[0], pp[1], pp[2] );
    }

    @property
    {
        void target( in vec3 tp ) { trg_point = tp; }
        vec3 target() const { return trg_point; }

        vec3 wayPoint() const { return way_point; }
    }

    void appendNear( in fRay[] d... ) { near ~= d; }

    ref const(UnitTrace) trace() const @property { return hist; }

protected:

    override void logic( float t, float dt )
    {
        calcWayPoint();
        cam.target = vec3( (matrix.inv * vec4(way_point,1)).xyz );
    }

    override void postProc()
    {
        hist.append( ph.pos );
    }

    override vec3 controlForce( float t, float dt )
    {
        auto flist =
            [
                limitedForce( pid( wayPoint - ph.pos, dt ) ),
                nearCorrect(),
            ];
        auto res = reduce!((r,a)=>(r+=a))( flist );
        return res + vec3(0,0,9.81*params.mass);
    }

    vec3 nearCorrect()
    {
        return vec3(0);
        //float max_dst = 4.8;
        //float max_dst2 = pow( max_dst, 2 );
        //auto mpts = data.getPoints( pos, max_dst );

        //return reduce!((r,pnt)
        //        {
        //            auto d = pnt - pos;
        //            auto dl = d.len;
        //            auto ve = vel.e;
        //            auto de = d.e;
        //            auto pv = dot(de,ve);
        //            auto nk = cross( cross( de, ve ), de );
        //            if( !nk ) nk = vec3(0);
        //            return r += ( -de * pow(max_dst-dl,2) * 2 + nk ) * max(0.001,pv) * 4;
        //            //return r += ( -de * pow(max_dst-dl,2) * 2 * max(0,pv) + nk * max(0.1,pv) ) * 4;
        //        })( vec3(0,0,0), filter!(a=>(a-pos).len2 < max_dst2)(
        //                chain( map!(a=>vec3(a.xyz))(filter!(a=>!(a.w<0.5))(mpts)),
        //                       map!(a=>a.pos)(dangers) ) ) );
    }

    void calcWayPoint()
    {
        //auto nv = data.nearestVolume(pos);

        //// сначала двигаемся к карте
        //if( nv.len2 > 0.001 )
        //{
        //    way_point = pos + nv;
        //    return;
        //}

        way_point = trg_point;
    }
}
