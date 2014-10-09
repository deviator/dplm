import std.stdio;
import des.app;
import draw.window;

void info(Args...)( Args args )
{
    stdout.writefln( args );
    stdout.flush();
}

void main()
{
    info( "app start" );
    GLApp app = new GLApp;
    app.addWindow({ return new MainWindow( "diploma simulator", ivec2(800,600) ); });
    app.run();
    app.destroy();
    info( "app finish" );
}
