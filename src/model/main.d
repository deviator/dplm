module model.main;

import std.stdio;

import des.math.linear;

import model.unit;

class Model
{
protected:

    Unit[] uarr;
    float time;

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

    void randomizeTargets()
    {
        auto rr = rndPos(50) + vec3(0,0,50);
        foreach( u; units )
            u.setTarget( rr, vec3(0,0,0) );
            //u.setTarget( u.coord.pos + rndPos(50), vec3(0,0,0) );
    }

    @property Unit[] units() { return uarr; }

protected:

    void logic( float dt )
    {
        processDanger();
    }

    void processDanger()
    {
        float danger_dist = 7;
        auto cnt = units.length;
        foreach( i; 0 .. cnt )
            foreach( j; 0 .. cnt )
            {
                if( i == j ) continue;
                auto a = units[i];
                auto b = units[j];
                if( (a.coord.pos - b.coord.pos).len2 < danger_dist * danger_dist )
                {
                    a.appendDanger( b.coord.pos );
                    b.appendDanger( a.coord.pos );
                }
            }
    }

    Unit createDefaultUnit()
    {
        auto buf = new Unit( vec3(0,0,20) + rndPos(5), vec3(1,0,0) );
        buf.setTarget( buf.coord.pos + rndPos(50), vec3(0,0,0) );
        return buf;
    }

    vec3 rndPos( float dst )
    {
        import std.random;
        auto uf() { return uniform(-dst,dst); }
        return vec3( uf, uf, uf*0.5 );
    }
}
