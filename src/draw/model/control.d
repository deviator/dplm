module draw.model.control;

import des.app.event;
import model;

import draw.object;

import draw.model.world;

class Control
{
private:
    Model model;
    World world;
    DrawUnit unit;

public:

    this( Model model )
    in{ assert( model !is null ); } body
    {
        world = new World( vec2(1000,1000), 300 );

        unit = new DrawUnit(null);
        unit.matrix = mat4(1,0,0,0,
                           0,1,0,0,
                           0,0,1,40,
                           0,0,0,1);
    }

    void idle()
    {

    }

    void draw( Camera cam )
    {
        world.draw( cam );
        unit.draw( cam );
    }

    void keyControl( in KeyboardEvent ev )
    {

    }
}
