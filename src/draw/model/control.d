module draw.model.control;

import des.app.event;
import des.util.timer;

import model;

import draw.object;

import draw.model.world;

class Control
{
private:
    Model mdl;
    World world;
    DrawUnit unit;

    Timer tm;

    bool model_proc = false;

public:

    this( Model model )
    in{ assert( model !is null ); } body
    {
        mdl = new Model;

        mdl.appendUnits( 20 );

        world = new World( vec2(400,400), 200 );
        unit = new DrawUnit(null);

        tm = new Timer;
    }

    void idle()
    {
        if( model_proc )
        {
            mdl.step( tm.cycle() );
        }
    }

    void draw( Camera cam )
    {
        world.draw( cam );
        foreach( u; mdl.units )
        {
            unit.color = col4(1,0,0,1);
            unit.setCoordinate( u.coord.pos, u.coord.rot );
            unit.draw( cam );

            unit.color = col4(0,0,1,1);
            unit.setCoordinate( u.targetPos, u.coord.rot );
            unit.draw( cam );
        }
    }

    void keyControl( in KeyboardEvent ev )
    {
        if( ev.scan == ev.Scan.P && ev.pressed )
        {
            tm.restart( 0.05 );
            model_proc = !model_proc;
        }

        if( ev.scan == ev.Scan.R && ev.pressed )
        {
            mdl.randomizeTargets();
        }
    }
}
