module model.main;

import std.stdio;

import des.math.linear;

import model.unit;
import model.worldmap;

class Model
{
protected:
    
    UnitParams uparams;
    Unit[] uarr;
    float time;

    float danger_dist = 5;
    vec2 mapsize;

    WorldMap wmap;

public:

    this( WorldMap worldmap )
    in{ assert( worldmap !is null ); } body
    {
        time = 0;
        wmap = worldmap;
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
        auto mapsize = vec3(wmap.size) * wmap.cellSize;
        foreach( u; units )
        {
            u.target = vec3( rndPos(mapsize.x/2).xy, rndPos(20).z + 22 );
            u.lookPnt = vec3( rndPos(mapsize.x/2).xy, 0 );
        }
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
            min_move = 0.2;

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
        auto s = vec3(0,0,130) + rndPos(10);
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
