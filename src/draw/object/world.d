module draw.object.world;

import std.algorithm;
import std.random;
import std.math;

import draw.object;

struct CCData
{
    vec3 pos, size;
    float angle = 0;
}

class World : DrawNodeList
{
    this( in vec2 size, float maxH )
    { regen( size, maxH ); }

    void regen( in vec2 size, float maxH )
    {
        foreach( o; list ) o.destroy();
        list.length = 0;

        genPlane( size * 2 );
        genRandomBuilds( size, maxH );
    }

    void genPlane( in vec2 size )
    {
        auto plane = newEMM!Plane(null);
        plane.setOffsetAndSize( vec3(0,0,0), size );
        list ~= plane;
    }

    void genRandomBuilds( in vec2 size, float maxH )
    {
        auto arr = genRandomCCData( size, vec3(5), vec3( 50, 50, maxH ), 50 );
        appendCCToList( arr );
    }

    CCData[] genRandomCCData( in vec2 lim, in vec3 minSize, in vec3 maxSize, size_t count )
    {
        CCData[] ret;

        foreach( i; 0 .. count )
        {
            CCData buf;

            buf.pos = rndVec3( vec3( -lim, 0 ), vec3( lim, 0 ) );
            buf.size = rndVec3( minSize, maxSize );
            buf.angle = uniform( 0.0f, PI );

            ret ~= buf;
        }
        return ret;
    }

    void appendCCToList( CCData[] arr )
    {
        auto mc = new MultiCube(null);
        foreach( c; arr )
            mc.addCube( c.pos, c.size, quat.fromAngle( c.angle, vec3(0,0,1) ) );
        list ~= mc;
    }
}

vec3 rndVec3( in vec3 minVal, in vec3 maxVal )
{
    return vec3( uniform!"[]"( minVal.x, maxVal.x ),
                 uniform!"[]"( minVal.y, maxVal.y ),
                 uniform!"[]"( minVal.z, maxVal.z ) );
}
