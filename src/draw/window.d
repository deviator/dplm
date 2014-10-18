module draw.window;

import des.util;

import des.app;

import draw.camera;
import draw.control;
import model;

import std.stdio;
import std.range;

class MainWindow : GLWindow
{
private:

    MCamera cam;
    Control ctrl;

    KeyboardEventProcessor keyproc;
    WindowEventProcessor   winproc;
    MouseEventProcessor    mouseproc;

protected:

    override void prepare()
    {
        createData();
        createEventProcessors();

        prepareSignals();
    }

    void createData()
    {
        cam  = new MCamera;
        ctrl = new Control( cam );
    }

    void createEventProcessors()
    {
        keyproc   = addEventProcessor( new KeyboardEventProcessor );
        winproc   = addEventProcessor( new WindowEventProcessor );
        mouseproc = addEventProcessor( new MouseEventProcessor );
    }

    void prepareSignals()
    {
        prepareBaseSignals();
        prepareDataSignals();
    }

    void prepareBaseSignals()
    {
        idle.connect({ glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT ); });

        keyproc.key.connect( ( in KeyboardEvent ev )
        {
            if( ev.scan == ev.Scan.ESCAPE )
            {
                ctrl.quit();
                app.quit();
            }
        });

        winproc.resized.connect(( ivec2 sz ){ glViewport( 0, 0, sz.x, sz.y ); });
    }

    void prepareDataSignals()
    {
        idle.connect({ ctrl.idle(); });
        draw.connect({ ctrl.draw(); });

        keyproc.key.connect( &(ctrl.keyControl) );
        keyproc.key.connect( &(cam.keyControl) );

        winproc.resized.connect( ( ivec2 sz )
        { cam.perspective.ratio = sz.x / cast(float)sz.y; });

        mouseproc.mouse.connect( &(cam.mouseControl) );
    }

public:

    this( string title, ivec2 sz, bool fullscreen = false )
    { super( title, sz, fullscreen ); }
}
