module draw.object.util;

public import des.math.linear;

import std.algorithm;
import std.array;
import std.range;
import std.math;

T[] multiElem(T)( size_t N, T val ) { return array( map!(a=>val)( iota(0,N) ) ); }

unittest
{
    assert( multiElem(3,"str") == [ "str", "str", "str" ] );
}

vec3[] figure_rot_Z( float angle, vec3[] arr )
{
    vec3[] ret;
    float m00, m01, m10, m11;
    m00 = m11 = cos(angle);
    m01 = -sin(angle);
    m10 = -m01;

    foreach( v; arr )
        ret ~= vec3( v.x * m00 + v.y * m01, v.x * m10 + v.y * m11, v.z );

    return ret;
}
