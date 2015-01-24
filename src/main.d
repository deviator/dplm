import std.stdio;
import des.app;
import draw.window;

import des.util.logsys;

void main()
{
    logger.info( "app start" );
    auto app = new DesApp;
    app.addWindow({ return new MainWindow( "diploma simulator", ivec2(800,600) ); });
    while( app.isRunning ) app.step();
    app.destroy();
    logger.info( "app finish" );
}
