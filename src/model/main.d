module model.main;

import std.stdio;
import std.random;

import des.math.linear;

import model.unit;
import model.dataaccess;

class Model
{
protected:
    
    UnitParams uparams;
    Unit[] uarr;
    float time;

    float danger_dist = 10;

    ModelDataAccess data;

public:

    this( ModelDataAccess mda )
    in{ assert( mda !is null ); } body
    {
        time = 0;
        data = mda;
        prepareParams();

        data.setUnitCamResolution( uparams.cam.res );
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
        auto mapsize = vec3(data.size) * data.cellSize;
        foreach( u; units )
        {
            u.target = vec3( rndPos(mapsize.x/2).xy, uniform(0.0f,20.0f) );
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
            gflim = 20;
            vfmin = -20;
            vfmax = 60;

            CxS = 0.15;
            mass = 0.5;

            ready.dst = 0.05;
            ready.vel = 0.01;
            min_move = 0.2;

            pid = [ vec3(3), vec3(0), vec3(1) ];

            cam.fov = 90;
            cam.min = 1;
            cam.max = 50;
            cam.res = ivec2(32,32);
            cam.rate = 5;
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
                    a.appendDanger( fRay( b.pos, b.vel ) );
                    b.appendDanger( fRay( a.pos, a.vel ) );
                }
            }
    }

    Unit createDefaultUnit()
    {
        auto s = vec3(0,0,80) + rndPos(1);
        auto buf = new Unit( PhVec(s,vec3(0)), uparams, data );
        buf.target = s;
        return buf;
    }

    vec3 rndPos( float dst )
    {
        auto uf() { return uniform(-dst,dst); }
        return vec3( uf, uf, uf*0.5 );
    }
}
