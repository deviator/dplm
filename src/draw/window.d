module draw.window;

import des.util;

import des.app;

import draw.control;

import std.stdio;
import std.range;

class MainWindow : DesWindow
{
private:

    Control ctrl;

protected:

    override void prepare()
    {
        ctrl = newEMM!Control();

        connect( idle, &(ctrl.idle) );
        connect( draw, &(ctrl.draw) );

        connect( key, ( in KeyboardEvent ev )
        {
            if( ev.scan == ev.Scan.ESCAPE )
            {
                ctrl.quit();
                app.quit();
            }
            else ctrl.keyReaction( ev );
        });

        connect( mouse, &(ctrl.mouseReaction) );

        connect( event.resized, ( ivec2 sz )
        {
            glViewport( 0, 0, sz.w, sz.h );
            ctrl.resize( sz );
        });
    }

public:

    this( string title, ivec2 sz, bool fullscreen = false )
    { super( title, sz, fullscreen ); }
}
