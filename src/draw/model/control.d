module draw.model.control;

import des.app.event;
import model;

class Control
{
private:
    Model model;

public:

    this( Model model )
    in{ assert( model !is null ); } body
    {
        
    }

    void idle()
    {

    }

    void draw( Camera cam )
    {

    }

    void keyControl( in KeyboardEvent ev )
    {

    }
}
