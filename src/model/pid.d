module model.pid;

import des.math.basic;

class PID(T) if( hasBasicMathOp!T )
{
    T P, I, D;

    T ibuf, dbuf;

    this( T p, T i, T d )
    {
        P = p;
        I = i;
        D = d;
    }

    T opCall( in T v, float dt )
    {
        return v * P +
            integral( v ) * I +
            derivative( v, dt ) * D;
    }

    T integral( in T v )
    {
        ibuf = ibuf + v;
        return ibuf;
    }

    T derivative( in T v, float dt )
    {
        auto dv = v - dbuf;
        dbuf = v;
        return dv / dt;
    }
}

class APID(T) : PID!T
{
    T add;

    this( T a, T p, T i, T d )
    {
        super(p,i,d);
        add = a;
    }

    override T opCall( in T v, float dt )
    { return super.opCall(v,dt) + add; }
}
