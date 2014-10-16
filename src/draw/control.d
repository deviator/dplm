module draw.control;

import des.app.event;
import des.util.timer;

import model;

import draw.object;

import draw.object.world;
import draw.render;

import des.il;

import std.stdio;

class Control
{
private:
    Model mdl;
    World world;
    DrawUnit draw_unit;

    Render render; 

    Timer tm;

    bool model_proc = false;
    bool view_depth_img = false;

    TextureView depth_view;

public:

    this( Model model )
    in{ assert( model !is null ); } body
    {
        mdl = new Model;

        mdl.appendUnits( 1 );

        world = new World( vec2(400,400), 200 );
        render = new Render;
        draw_unit = new DrawUnit(null);
        depth_view = new TextureView;

        tm = new Timer;
    }

    void idle()
    {
        if( model_proc )
        {
            foreach( u; mdl.units )
                if( u.nearTarget && u.readyToSnapshot )
                {
                    render( u.snapshotResolution, { world.draw( u.camera ); } );
                    Image!2 buf = render.depthImage.dup;

                    buf.pixel!float(1,1) = 1;
                    buf.pixel!float(2,2) = 1;
                    buf.pixel!float(2,1) = 0;
                    buf.pixel!float(1,2) = 0;

                    depth_view.setImage( buf );
                    u.addSnapshot( buf );
                }
            mdl.step( tm.cycle() );
        }
    }

    void draw( Camera cam )
    {
        world.draw( cam );

        foreach( i, u; mdl.units )
        {
            if( u.nearTarget )
                draw_unit.color = col4(0,1,0,1);
            else
                draw_unit.color = col4(1,0,0,1);
            draw_unit.setCoordinate( u.pos, u.rot );
            draw_unit.draw( cam );

            draw_unit.color = col4(0,0,1,0.5);
            draw_unit.setCoordinate( u.target, u.rot );
            draw_unit.draw( cam );
        }

        if( view_depth_img )
        {
            depth_view.draw({ render.bindDepthTexture(); });
            //depth_view.draw();
        }
    }

    void keyControl( in KeyboardEvent ev )
    {
        if( ev.scan == ev.Scan.P && ev.pressed )
        {
            tm.restart( 0.05 );
            model_proc = !model_proc;
        }

        /+ TODO: remove +/
        if( ev.scan == ev.Scan.R && ev.pressed )
        {
            mdl.randomizeTargets();
        }

        if( ev.scan == ev.Scan.D && ev.pressed )
        {
            view_depth_img = !view_depth_img;
        }
    }
}
