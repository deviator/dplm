import std.stdio;
import des.app;
import draw.window;

import des.util;

void main()
{
    log_info( "app start" );
    GLApp app = new GLApp;
    app.addWindow({ return new MainWindow( "diploma simulator", ivec2(800,600) ); });
    app.run();
    app.destroy();
    log_info( "app finish" );
}
