module model.main;

import std.stdio;

import des.math.linear;

import model.unit;
import model.worldmap;

class Model
{
protected:

    WorldMap wmap;
    
    UnitParams uparams;
    Unit[] uarr;
    float time;

    float danger_dist = 5;

public:
    this( ivec3 mapres )
    {
        time = 0;
        wmap = new WorldMap( mapres, mat4().setCol(3,vec4(mapres.x,mapres.y,0,1)) );

        prepareParams();
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
        foreach( u; units )
            u.target = u.pos + vec3( rndPos(50).xy, rndPos(10).z );
    }

    @property Unit[] units() { return uarr; }

protected:

    void prepareParams()
    {
        auto glim = vec2(20);

        with(uparams)
        {
            flim.min = vec3(-glim,0);
            flim.max = vec3(glim,60);

            CxS = 0.1;
            mass = 2;

            ready.dst = 0.05;
            ready.vel = 0.01;

            apid = [ vec3(0,0,9.81*2),
                     vec3(3),
                     vec3(0),
                     vec3(4) ];

            cam.fov = 90;
            cam.min = 1;
            cam.max = 150;
            cam.size = ivec2(32,32);
            cam.rate = 2;
        }
    }

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
        auto s = vec3(0,0,30) + rndPos(10);
        auto buf = new Unit( PhVec(s,vec3(0)), uparams, wmap );
        buf.target = s;
        return buf;
    }

    vec3 rndPos( float dst )
    {
        import std.random;
        auto uf() { return uniform(-dst,dst); }
        return vec3( uf, uf, uf*0.5 );
    }
}
