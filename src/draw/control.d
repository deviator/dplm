module draw.control;

import des.util.arch;
import des.util.logsys;

import des.il;
import des.app.event;

import des.gl.base.render;

import model;

import draw.object;
import draw.camera;

import draw.object.world;
import draw.object.point;
import draw.object.plane;
import draw.object.line;
import draw.worldmap;

import compute;

struct ModelConfig
{
    float h = 0.1f;
    size_t unit_count = 5;
}

class Control : DesObject
{
    mixin DES;

private:
    CLGLEnv env;

    Model mdl;
    World world;
    CLWorldMap worldmap;
    DrawUnit draw_unit;
    CalcPoint ddot;
    Line track;

    GLRenderToTex render;

    bool model_proc = true;

    Image!2 buf_depth;
    vec3 buf_target;

    bool watch_copter = true;

    MCamera cam;

    bool draw_world_in_view = true;

    ModelConfig mdlcfg;

public:

    this()
    {
        logger.trace( "create control start" );

        prepareCLGLEnv();

        cam = new MCamera;

        ddot = newEMM!CalcPoint( env, null );

        worldmap = newEMM!CLWorldMap( env, ivec3(200,200,50), vec3(1), ddot.cdata );
        worldmap.needDraw = false;

        mdl = newEMM!Model( worldmap );

        mdl.appendUnits( mdlcfg.unit_count );
        worldmap.setUnitCount( mdlcfg.unit_count );

        world = newEMM!World( vec2(200,200), 50 );
        render = newEMM!GLRenderToTex;
        draw_unit = newEMM!DrawUnit(null);
        track = newEMM!Line;

        ddot.color = col4(0,1,0,1);
        ddot.size(2);

        track.width(2);
        track.color = col4(0,1,0,1);

        logger.trace( "create control complite" );
    }

    void idle()
    {
        if( mdl.units.length )
        {
            buf_target = mdl.units[$-1].target;

            if( watch_copter )
                cam.target = mdl.units[$-1].pos;
        }

        if( model_proc )
        {
            foreach( u; mdl.units )
                if( u.readyToSnapshot )
                {
                    render( u.snapshotResolution,
                    {
                        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
                        world.draw( u.camera );
                    });
                    render.depth.getImage( buf_depth );
                    u.addSnapshot( buf_depth );
                }
            mdl.step( mdlcfg.h );
            worldmap.process();
        }
    }

    void draw()
    {
        glClearColor(1,1,1,1);
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

        if( draw_world_in_view )
            world.draw( cam );

        foreach( i, u; mdl.units )
        {
            if( u.nearTarget )
                draw_unit.color = col4(0,1,0,1);
            else
                draw_unit.color = col4(0,0,1,1);
            draw_unit.setParent( u );
            draw_unit.draw( cam );

            draw_unit.color = col4(1,0,1,0.5);
            draw_unit.setCoordinate( u.wayPoint, quat(0,0,0,1) );
            draw_unit.draw( cam );

            draw_unit.color = col4(0,1,1,0.5);
            draw_unit.setCoordinate( u.target, quat(0,0,0,1) );
            draw_unit.draw( cam );

            ddot.draw( cam );

            track.set( u.currentTrack );
            track.draw( cam );
        }

        worldmap.draw( cam );
    }

    void quit() { }

    void keyReaction( in KeyboardEvent ev )
    {
        auto trg = mdl.units[$-1].target;
        if( ev.pressed )
        {
            switch( ev.scan )
            {
                case ev.Scan.P:
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

                case ev.Scan.UP:
                    mdl.units[$-1].target = trg + vec3(1,0,0) * 0.1;
                    break;
                case ev.Scan.DOWN:
                    mdl.units[$-1].target = trg - vec3(1,0,0) * 0.1;
                    break;
                case ev.Scan.LEFT:
                    mdl.units[$-1].target = trg + vec3(0,1,0) * 0.1;
                    break;
                case ev.Scan.RIGHT:
                    mdl.units[$-1].target = trg - vec3(0,1,0) * 0.1;
                    break;
                case ev.Scan.I:
                    mdl.units[$-1].target = vec3(-1,0,1);
                    break;

                case ev.Scan.G:
                    world.regen( vec2(200,200), 100 );
                    break;

                case ev.Scan.NUMBER_1:
                    cam.target = buf_target;
                    break;

                case ev.Scan.NUMBER_2:
                    watch_copter = !watch_copter;
                    break;

                default: cam.keyReaction( ev );
            }
        }
    }

    void mouseReaction( in MouseEvent ev ) { cam.mouseReaction( ev ); }
    void resize( ivec2 sz ) { cam.ratio = sz.w / cast(float)sz.h; }

protected:
    
    void prepareCLGLEnv()
    {
        import std.file;
        import des.util.helpers;
        env = newEMM!CLGLEnv( readText( appPath( "..", "data", "compute", "main.cl" ) ) );
    }
}
