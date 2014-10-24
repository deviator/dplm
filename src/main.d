import std.stdio;
import des.app;
import draw.window;

import des.util;

void info(Args...)( Args args )
{
    stdout.writefln( args );
    stdout.flush();
}

void main()
{
    log_trace( "app start" );
    GLApp app = new GLApp;
    app.addWindow({ return new MainWindow( "diploma simulator", ivec2(800,600) ); });
    app.run();
    app.destroy();
    log_trace( "app finish" );
}
