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

public:

    this( Model model )
    in{ assert( model !is null ); } body
    {
        world = new World( vec2(1000,1000), 300 );
    }

    void idle()
    {

    }

    void draw( Camera cam )
    {
        world.draw( cam );
    }

    void keyControl( in KeyboardEvent ev )
    {

    }
}
