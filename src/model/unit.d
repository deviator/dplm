module model.unit;

import std.math;
import std.range;
import std.typecons;
import std.algorithm;

import std.stdio;
import std.random;

import des.math.linear;
import des.math.basic;
import des.space;

import des.il;

import des.util.arch;
import des.util.logsys;

import model.mapaccess;
import model.pid;
import model.camera;

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
        logger.trace( " " );
    }

protected:

    ///
    abstract void logic( float t, float dt );

    /// calc control force 
    abstract vec3 controlForce( float t, float dt );

    final UnitState rpart( float t, float dt )
    {
        auto cf = limitedForce( controlForce( t, dt ) );
        auto df = dragForce();
        logger.trace( "drag force: ", df );
        if( df.len / 3 > cf.len ) df = df.e * cf.len * 3;
        logger.trace( "limited drag force: ", df );

        auto f = df + cf;

        UnitState ret;
        ret.pos = state.vel;
        ret.vel = f / params.mass + vec3(0,0,-9.81);

        logger.Debug( "sum force: ", ret );

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

    ///
    fRay[] near;

    ///
    UnitTrace hist;

    ///
    PID!vec3 pid;

    ///
    MapAccess map;

public:

    ///
    this( UnitState initial, UnitParams prms, MapAccess map, vec3[3] pp )
    in { assert( map !is null ); } body
    {
        super( initial, prms );
        this.map = map;
        trg_point = initial.pos;
        pid = new PID!vec3( pp[0], pp[1], pp[2] );
    }

    @property
    {
        ///
        void target( in vec3 tp ) { trg_point = tp; }
        ///
        vec3 target() const { return trg_point; }
        ///
        vec3 wayPoint() const { return way_point; }
    }

    ///
    void appendNear( in fRay[] d... ) { near ~= d; }

    ///
    ref const(UnitTrace) trace() const @property { return hist; }

protected:

    override void logic( float t, float dt )
    {
        getNear();
        calcWayPoint();
        cam.target = vec3( (matrix.inv * vec4(way_point,1)).xyz );
    }

    void getNear()
    {
        auto mr = map.getRegion( fRegion3( ph.pos - vec3(3), vec3(6) ) );
        foreach( i, me; mr.img.mapAs!MapElement )
        {
            if( me.meas != 0 && me.val.x <= 0 ) continue;
            near ~= fRay( mr.toWorld(i), vec3(0) );
        }
    }

    override void postProc()
    {
        hist.append( ph.pos );
    }

    override vec3 controlForce( float t, float dt )
    {
        logger.trace( "wayPoint: ", wayPoint );
        logger.trace( "ph.pos: ", ph.pos );
        logger.trace( "diff: ", wayPoint - ph.pos, " dt: ", dt );
        auto pidval = pid( wayPoint - ph.pos, dt );
        logger.trace( "pidval: ", pidval );
        auto limpidval = limitedForce( pidval );
        logger.trace( "limpidval: ", limpidval );

        auto nc = nearCorrect();
        logger.trace( "nc: ", nc );
        auto limnc = limitedForce( nc / 100.0 ) * 100.0;
        logger.trace( "limnc: ", limnc );

        return reduce!((r,a)=>(r+=a))( [
            limpidval,
            limnc,
            vec3(0,0,9.81) * params.mass,
        ] );
    }

    void calcWayPoint()
    {
        way_point = trg_point;
    }

    vec3 nearCorrect()
    {
        float max_dst = 4.8;
        float max_dst2 = pow( max_dst, 2 );

        vec3 ret;

        foreach( danger; near )
        {
            auto d = danger.pos - ph.pos;
            auto dl = d.len;
            auto ve = ph.vel.e;
            auto de = d.e;
            auto pv = dot( de, ve );
            auto nk = cross( cross( de, ve ), de );
            if( !nk ) nk = vec3(0);

            ret += ( -de * pow(max_dst-dl,2) * 2 + nk ) * max(0.001,pv) * 4;
        }
        near.length = 0;

        return ret;
    }
}

class AutoTargetUnit : Unit
{
    this( UnitState initial, UnitParams prms, MapAccess map, vec3[3] pp )
    in { assert( map !is null ); } body
    { super( initial, prms, map, pp ); }

protected:

    override void logic( float t, float dt )
    {
        retargetLogic();
        super.logic( t, dt );
    }

    size_t skip_rnd;
    size_t est_cnt = 20;

    void retargetLogic()
    {
        skip_rnd++;
        if( !needNewTarget() || skip_rnd < est_cnt ) return;
        skip_rnd = 0;
        choiseTarget();
    }

    bool needNewTarget()
    {
        float min_var = 5;

        if( hist.data.length < est_cnt )
            return false;

        float est = 0;
        foreach( t; hist.data[$-est_cnt..$] )
            est += (target - t).len;
        est /= est_cnt;

        float var = 0;
        foreach( t; hist.data[$-est_cnt..$] )
            var += pow( est - (target - t).len, 2 );
        var /= est_cnt - 1;

        return var < min_var;
    }

    abstract void choiseTarget();
}

class RndTargetUnit : AutoTargetUnit
{
    this( UnitState initial, UnitParams prms, MapAccess map, vec3[3] pp )
    in { assert( map !is null ); } body
    { super( initial, prms, map, pp ); }

protected:

    override void choiseTarget()
    {
        auto u( float dst ) @property { return uniform(-dst,dst); }
        target = vec3( u(200), u(200), u(25) + 25 );
    }
}

class FindTargetUnit : AutoTargetUnit
{
    this( UnitState initial, UnitParams prms, MapAccess map, vec3[3] pp )
    in { assert( map !is null ); } body
    { super( initial, prms, map, pp ); }

protected:

    float step = 5.0f;

    override void choiseTarget()
    {
        auto offset = vec2(step) * 10;

        float angle = uniform(0,PI_2);

        auto pts = 
        [
            findTargetAround( vec3( ph.pos.xy + rotate( offset * vec2( 1, 0), angle ), 0 ) ),
            findTargetAround( vec3( ph.pos.xy + rotate( offset * vec2(-1, 0), angle ), 0 ) ),
            findTargetAround( vec3( ph.pos.xy + rotate( offset * vec2( 0, 1), angle ), 0 ) ),
            findTargetAround( vec3( ph.pos.xy + rotate( offset * vec2( 0,-1), angle ), 0 ) ),
        ];

        typeof(pts[0]) choisen;
        foreach( p; pts ) if( choisen.weight < p.weight ) choisen = p;

        target = choisen.center;
    }

    struct Unknown
    {
        float weight = 0;
        vec3 center;
    }

    vec2 rotate( vec2 v, float a )
    {
        return vec2( v.x * cos(a) + v.y * sin(a),
                    -v.x * sin(a) + v.y * cos(a) );
    }

    auto findTargetAround( vec3 p )
    {
        auto mr = map.getRegion( fRegion3( p - vec3(step,step,0), vec3(step,step,25) * 2 ) );

        Unknown ret;

        foreach( i, me; mr.img.mapAs!MapElement )
        {
            if( me.meas == 0 )
            {
                ret.weight++;
                ret.center += mr.toWorld(i);
            }
        }

        ret.center /= ret.weight;
        return ret;
    }
}

class SerialTargetUnit : AutoTargetUnit
{
protected:
    static size_t stu_count;
    size_t id;
    size_t sector_number;
    size_t target_number;

    immutable static 
    {
        vec3 offset = vec3(-200,-200,0);

        vec3 cell0 = vec3(100,100,50);
        CoordType[3] res0 = [ 4, 4, 1 ];

        vec3 cell = vec3(10);
        CoordType[3] res = [ 10, 10, 5 ];
        
        size_t mcnt0 = res0[0] * res0[1] * res0[2];
        size_t mcnt = res[0] * res[1] * res[2];
    }

public:

    this( UnitState initial, UnitParams prms, MapAccess map, vec3[3] pp )
    in { assert( map !is null ); } body
    {
        super( initial, prms, map, pp );
        id = stu_count++;
        sector_number = id % ( res0[0] * res0[1] * res0[2] );
        target_number = id;
    }

protected:

    override void choiseTarget()
    {
        target_number += stu_count;

        target = offset + vec3( getCoord( res0, sector_number ) ) * cell0 +
                ( vec3( getCoord( res, target_number % mcnt ) ) + vec3(0.5) ) * cell;
    }
}
