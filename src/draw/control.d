module draw.control;

import des.app.event;
import des.util.timer;

import model;

import draw.object;
import draw.camera;

import draw.object.world;
import draw.object.point;
import draw.object.plane;
import draw.worldmap;

import des.gl.post.render;

import des.il;

import std.stdio;

class Control
{
private:
    Model mdl;
    World world;
    CLWorldMap worldmap;
    DrawUnit draw_unit;
    Point ddot;

    Render render; 

    Timer tm;

    bool model_proc = true;

    Image!2 buf_depth;
    vec3 buf_target;

    MCamera cam;

    bool draw_world_in_view = true;

public:

    this( MCamera c )
    {
        cam = c;

        worldmap = new CLWorldMap( ivec3(100,100,25), vec3(1) );

        mdl = new Model( worldmap );

        mdl.appendUnits( 20 );

        world = new World( vec2(100,100), 50 );
        render = new Render;
        draw_unit = new DrawUnit(null);

        ddot = new Point(null);

        tm = new Timer;
    }

    void idle()
    {
        if( mdl.units.length )
            buf_target = mdl.units[$-1].target;

        if( model_proc )
        {
            foreach( u; mdl.units )
                if( u.readyToSnapshot )
                {
                    render( u.snapshotResolution,
                    { world.draw( u.camera ); });
                    render.depth.getImage( buf_depth );
                    u.addSnapshot( buf_depth );
                }
            mdl.step( tm.cycle() );
            worldmap.process();
        }
    }

    void draw()
    {
        if( draw_world_in_view )
            world.draw( cam );

        ddot.reset();

        foreach( i, u; mdl.units )
        {
            if( u.nearTarget )
                draw_unit.color = col4(0,1,0,1);
            else
                draw_unit.color = col4(1,0,0,1);
            draw_unit.setParent(u);
            draw_unit.draw( cam );

            draw_unit.color = col4(0,0,1,0.5);
            draw_unit.setCoordinate( u.target, u.rot );
            draw_unit.draw( cam );

            ddot.add( u.lastSnapshot );
            ddot.draw( cam );
        }

        worldmap.draw( cam );
    }

    void quit() { }

    void keyControl( in KeyboardEvent ev )
    {
        if( ev.pressed )
        {
            switch( ev.scan )
            {
                case ev.Scan.P:
                    tm.restart( 0.05 );
                    model_proc = !model_proc;
                    break;

                case ev.Scan.W:
                    draw_world_in_view = !draw_world_in_view;
                    break;

                case ev.Scan.D:
                    ddot.needDraw = !ddot.needDraw;
                    break;

                case ev.Scan.M:
                    worldmap.needDraw = !worldmap.needDraw;
                    break;

                /+ TODO: remove +/
                case ev.Scan.R:
                    mdl.randomizeTargets();
                    break;

                case ev.Scan.G:
                    world.regen( vec2(400,400), 200 );
                    break;

                case ev.Scan.NUMBER_1:
                    cam.target = buf_target;
                    break;

                default: break;
            }
        }
    }
}
