module model.main;

import std.stdio;
import std.random;

import des.math.linear;
import des.util.arch;

import model.mapaccess;
import model.unit;

struct ModelConfig
{
    /// integration step
    float h;

    ///
    size_t unit_count;

    ///
    uivec2 camres = uivec2(32,32);

    invariant() { assert( h > 0 ); }
}

class Model : DesObject
{
protected:

    float tm = 0;
    
    UnitParams unit_params;

    ModelConfig cfg;
    MapAccess map;

public:

    Unit[] units;

    this( ModelConfig cfg, MapAccess map )
    in { assert( map !is null ); } body
    {
        this.cfg = cfg;
        this.map = map;
        createUnits();
    }

    float time() const @property { return tm; }

    ref const(ModelConfig) config() const @property { return cfg; }

    void process()
    {
        tm += cfg.h;
        logic( cfg.h );
        foreach( unit; units )
            unit.process( tm, cfg.h );
    }

    void randomizeTargets()
    {
        foreach( unit; units )
            unit.target = vec3( rndPos(200).xy, uniform(1.0f, 20.0f) );
    }

protected:

    void createUnits()
    {
        prepareParams();
        foreach( i; 0 .. cfg.unit_count )
            units ~= createDefaultUnit();
    }

    void prepareParams()
    {
        with(unit_params)
        {
            hflim = 20;
            vfmin = -20;
            vfmax = 60;

            CxS = 0.5;
            mass = 0.5;

            cam.fov = 90;
            cam.near = 1;
            cam.far = 50;
            cam.res = cfg.camres;
        }
    }

    void logic( float dt )
    {
        processDangerUnits();
    }

    void processDangerUnits()
    {
        auto cnt = units.length;
        float danger_dist = 5;
        foreach( i; 0 .. cnt )
            foreach( j; 0 .. cnt )
            {
                if( i == j ) continue;
                auto a = units[i];
                auto b = units[j];
                if( (a.state.pos - b.state.pos).len2 < danger_dist * danger_dist )
                {
                    a.appendNear( fRay( b.state.pos, b.state.vel ) );
                    b.appendNear( fRay( a.state.pos, a.state.vel ) );
                }
            }
    }

    Unit createDefaultUnit()
    {
        auto s = vec3(0,0,80) + rndPos(5);
        vec3[3] pid = [ vec3(3), vec3(0), vec3(1) ];
        auto buf = newUnit( UnitState( s, vec3(0) ), unit_params, map, pid );
        buf.target = s + rndPos(0.1);
        return buf;
    }

    //Unit newUnit( UnitState i, UnitParams p, MapAccess m, vec3[3] pid )
    //{ return newEMM!RndTargetUnit( i, p, m, pid ); }

    //Unit newUnit( UnitState i, UnitParams p, MapAccess m, vec3[3] pid )
    //{ return newEMM!FindTargetUnit( i, p, m, pid ); }

    Unit newUnit( UnitState i, UnitParams p, MapAccess m, vec3[3] pid )
    { return newEMM!SerialTargetUnit( i, p, m, pid ); }

    vec3 rndPos( float dst )
    {
        auto uf() @property { return uniform(-dst,dst); }
        return vec3( uf, uf, uf );
    }
}
