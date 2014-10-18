module draw.control;

import des.app.event;
import des.util.timer;

import model;

import draw.object;
import draw.camera;

import draw.object.world;
import draw.object.point;
import draw.object.plane;
import des.gl.post.render;

import des.il;

import std.stdio;

class Control
{
private:
    Model mdl;
    World world;
    DrawUnit draw_unit;
    Point ddot;
    //Point error, test;

    Render render; 

    Timer tm;

    bool model_proc = true;
    bool view_depth_img = false;

    TextureView depth_view;

    Image!2 buf_depth;
    vec3 buf_target;

    //Plane pA, pB;

    MCamera cam;

public:

    this( Model model, MCamera c )
    in{ assert( model !is null ); } body
    {
        cam = c;
        mdl = new Model;

        mdl.appendUnits( 1 );

        world = new World( vec2(400,400), 200 );
        render = new Render;
        draw_unit = new DrawUnit(null);
        depth_view = new TextureView;

        /+
        pA = new Plane(null);
        pA.setOffsetAndSize( vec3(0,0,0), vec2(400,400) );
        pB = new Plane(null);
        pB.matrix = mat4(0,0,3,0,
                         0,3,0,0,
                         3,0,0,0,
                         0,0,0,1);
        +/

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
                //if( u.nearTarget && u.readyToSnapshot )
                if( u.readyToSnapshot )
                {
                    render( u.snapshotResolution,
                    {
                        world.draw( u.camera );
                    });
                    render.depth.getImage( buf_depth );
                    u.addSnapshot( buf_depth );
                }
            mdl.step( tm.cycle() );
        }
    }

    void draw()
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

            ddot.setParent( draw_unit );
            ddot.set( u.lastSnapshot );
            ddot.draw( cam );

            draw_unit.color = col4(0,0,1,0.5);
            draw_unit.setCoordinate( u.target, u.rot );
            draw_unit.draw( cam );
        }

        if( view_depth_img )
            depth_view.draw(
            {
                render.depth.bind();
                auto ir = cast(float)( buf_depth.size.w ) / buf_depth.size.h;
                int[4] vp;
                glGetIntegerv( GL_VIEWPORT, vp.ptr );
                auto vr = cast(float)( vp[2] ) / vp[3];
                depth_view.setImgRatio(ir);
                depth_view.setViewRatio(vr);
                depth_view.setScale( vec2(0.3,0.3) );
                depth_view.setOffset( vec2(-0.5,-0.5) );
            });
    }

    void quit() { }

    void keyControl( in KeyboardEvent ev )
    {
        if( ev.pressed )
        {
                    auto t = mdl.units[$-1].target;
            switch( ev.scan )
            {
                case ev.Scan.P:
                    tm.restart( 0.05 );
                    model_proc = !model_proc;
                    break;

                /+ TODO: remove +/
                case ev.Scan.R:
                    mdl.randomizeTargets();
                    break;

                case ev.Scan.D:
                    view_depth_img = !view_depth_img;
                    break;

                case ev.Scan.G:
                    world.regen( vec2(400,400), 200 );
                    break;

                case ev.Scan.NUMBER_1:
                    cam.target = buf_target;
                    break;

                case ev.Scan.H:
                    mdl.units[$-1].target = vec3( t.x+0.1, t.yz );
                    //world.regen( vec2(400,400), 200 );
                    break;

                case ev.Scan.L:
                    mdl.units[$-1].target = vec3( t.x-0.1, t.yz );
                    break;


                default: break;
            }
        }
    }
}
