module model.main;

import std.stdio;

import des.math.linear;

import model.unit;

class Model
{
protected:

    Unit[] uarr;
    float time;

    float danger_dist = 5;

public:
    this()
    {
        time = 0;
    }

    void step( float dt )
    {
        time += dt;
        logic( dt );
        foreach( unit; uarr )
            unit.step( time, dt );
    }

    void appendUnits( size_t n )
    {
        foreach( i; 0 .. n )
            uarr ~= createDefaultUnit();
    }

    /+ TODO: remove +/
    void randomizeTargets()
    {
        auto rr = rndPos(50) + vec3(0,0,20);
        foreach( u; units )
            u.target = rr;
            //u.target = u.pos + rndPos(50);;
    }

    @property Unit[] units() { return uarr; }

protected:

    void logic( float dt )
    {
        processDangerUnits();
    }

    void processDangerUnits()
    {
        auto cnt = units.length;
        foreach( i; 0 .. cnt )
            foreach( j; 0 .. cnt )
            {
                if( i == j ) continue;
                auto a = units[i];
                auto b = units[j];
                if( (a.pos - b.pos).len2 < danger_dist * danger_dist )
                {
                    a.appendDanger( b.pos );
                    b.appendDanger( a.pos );
                }
            }
    }

    Unit createDefaultUnit()
    {
        auto buf = new Unit( PhVec( vec3(0,0,20) + rndPos(5), vec3(1,0,0) ),
                             UnitParams( vec2(20), 0, 60 ) );
        buf.target = buf.pos + rndPos(50);
        return buf;
    }

    vec3 rndPos( float dst )
    {
        import std.random;
        auto uf() { return uniform(-dst,dst); }
        return vec3( uf, uf, uf*0.5 );
    }
}
