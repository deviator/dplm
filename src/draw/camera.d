module draw.camera;

import des.math.linear;
import std.math;

class MCamera : Camera
{
protected:
    LookAtTransform look_tr;

    vec2 rot;

    float y_angle_limit = PI_2 - 0.01;

public:

    PerspectiveTransform perspective;

    this()
    {
        super();
        look_tr = new LookAtTransform;
        look_tr.pos = vec3(10,20,5);
        look_tr.target = vec3(0,0,0);
        look_tr.up = vec3(0,0,1);
        transform = look_tr;
        perspective = new PerspectiveTransform; 
        projection = perspective;
    }

    void addRotate( in vec2 angle )
    {
        rot = normRotate( rot + angle );
        look_tr.pos = vec3( cos(rot.x) * cos(rot.y),
                            sin(rot.x) * cos(rot.y),
                            sin(rot.y) ) * look_tr.pos.len;
    }

    void moveFront( float dist )
    {
        look_tr.pos += look_tr.pos * dist;
        if( look_tr.pos.len2 < 1 )
            look_tr.pos = look_tr.pos.e;
    }

protected:

    vec2 normRotate( in vec2 r )
    {
        vec2 ret = r;
        if( ret.y > y_angle_limit ) ret.y = y_angle_limit;
        if( ret.y < -y_angle_limit ) ret.y = -y_angle_limit;
        return ret;
    }
}
