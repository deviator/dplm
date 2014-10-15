module model.unit;

import des.math.linear;
import des.math.basic;

import model.pid;

struct UnitCoordinate
{
    vec3 pos;
    quat rot;
}

struct PhVec
{
    vec3 pos, vel;
    quat rot;

    mixin( BasicMathOp!"pos vel rot" );
}

class Unit
{
protected:

    PhVec phcrd;

    enum vec2 glim = vec2(20);

    vec3 flim_min = -vec3(glim,0),
         flim_max =  vec3(glim,60);

    float CxS = 0.1;
    float mass = 2;

    vec3 target_pos, target_view;
    vec3[] dangers;

    PIDA!vec3 pos_PIDA;

public:

    this( vec3 pos, vec3 vel=vec3(0), quat r=quat(0,0,0,1) )
    {
        phcrd = PhVec( pos, vel, r );
        target_pos = pos;
        target_view = pos + r.rot( vec3(1,0,0) );

        pos_PIDA = new PIDA!vec3( vec3(3), vec3(0), vec3(3), vec3(0,0,mass*9.81) );
    }

    void step( float t, float dt )
    { phcrd += rpart( t, dt ) * dt; }

    @property UnitCoordinate coord() const
    { return UnitCoordinate( phcrd.pos, phcrd.rot ); }

    @property PhVec phaseCoord() const { return phcrd; }

    void setTarget( in vec3 pos, in vec3 view )
    {
        target_pos = pos;
        target_view = view;
    }

    void appendDanger( in vec3 d ) { dangers ~= d; }

    @property vec3 targetPos() const { return target_pos; }

protected:

    PhVec rpart( float t, float dt )
    {
        auto f = drag( phcrd.vel, 1 ) + controlForce( dt );
        auto a = f / mass + vec3(0,0,-9.81);

        PhVec ret;
        ret.pos = phcrd.vel;
        ret.vel = a;
        ret.rot = quat(0);

        return ret;
    }

    vec3 drag( in vec3 vel, float rho )
    { return -vel * vel.len * CxS * rho / 2; }

    vec3 controlForce( float dt )
    {
        vec3 res;
        res += pos_PIDA( target_pos - phcrd.pos, dt );
        res += dangerProcess() * vec3(500);

        return limited( res, flim_max, flim_min );
    }

    vec3 dangerProcess()
    {
        if( dangers.length == 0 )
            return vec3(0);

        vec3 ret;
        foreach( d; dangers )
        {
            auto dst = coord.pos - d;
            ret += dst.e / ( dst.len2 + 0.1 );
        }
        ret /= dangers.length;
        dangers.length = 0;
        return ret;
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
