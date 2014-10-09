module draw.window;

import des.util;

import des.app;

import draw.camera;
import draw.object;

import std.stdio;
import std.range;

class MainWindow : GLWindow
{
private:

    MCamera  cam;
    Cube[]   cubes;

protected:

    override void prepare()
    {
        cam = new MCamera;

        auto offsets =
        [
            vec3(0,0,0),
            vec3(3,0,0),
            vec3(6,0,0)
        ];

        auto colors =
        [
            col4(1,0,0,1),
            col4(0,1,0,1),
            col4(0,0,1,1)
        ];

        foreach( prm; zip(offsets,colors) )
            addCube( prm[0], prm[1] );

        idle.connect(
        {
            glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        });

        draw.connect(
        {
            foreach( cube; cubes )
                cube.draw( cam );
        });

        auto keyproc   = addEventProcessor( new KeyboardEventProcessor );
        auto winproc   = addEventProcessor( new WindowEventProcessor );
        auto mouseproc = addEventProcessor( new MouseEventProcessor );

        keyproc.key.connect( ( in KeyboardEvent ev )
        {
            if( ev.scan == ev.Scan.ESCAPE ) app.quit();
        });

        winproc.resized.connect( ( ivec2 sz )
        {
            cam.perspective.aspect = sz.x / cast(float)sz.y;
            glViewport( 0, 0, sz.x, sz.y );
        });

        mouseproc.mouse.connect( &(cam.mouseControl) );
    }

    void addCube( vec3 offset, col4 color )
    {
        auto cube_offset = new DimmyNode;
        cube_offset.setOffset( offset );
        auto nc = registerChildEMM( new Cube( cube_offset ) );
        nc.color = color;
        cubes ~= nc;
    }

public:

    this( string title, ivec2 sz, bool fullscreen = false, int display = -1 )
    { super( title, sz, fullscreen ); }
}
