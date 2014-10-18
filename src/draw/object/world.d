module draw.object.world;

import draw.object;

import std.stdio;

struct CCData
{
    ivec3 pos, size;
    bool has( in ivec3 p ) const
    {
        return p.x >= pos.x &&
               p.y >= pos.y &&
               p.z >= pos.z &&
               p.x < pos.x + size.x &&
               p.y < pos.y + size.y &&
               p.z < pos.z + size.z;
    }
}

class World : DrawNodeList
{
    this( in vec2 size, float maxH, in vec3 minBlock=vec3(10,10,4),
                                    in vec3 maxBlock=vec3(100,100,40) )
    { regen( size, maxH, minBlock, maxBlock ); }

    void regen( in vec2 size, float maxH, in vec3 minBlock=vec3(10,10,4),
                                        in vec3 maxBlock=vec3(100,100,40) )
    {
        foreach( o; list ) o.destroy();
        list.length = 0;

        genPlane( size * 2 );
        genRandomBuilds( -size, size, maxH, minBlock, maxBlock, vec3(10,10,2) );
    }

    void genPlane( in vec2 size )
    {
        auto plane = new Plane(null);
        plane.setOffsetAndSize( vec3(0,0,0), size );
        list ~= plane;
    }

    void genRandomBuilds( in vec2 minPos, in vec2 maxPos, float maxH,
            in vec3 minBlock, in vec3 maxBlock, in vec3 step,
            size_t count=100 )
    {
        auto volume = ivec3( (maxPos-minPos) / step.xy, maxH / step.z );
        auto minB = ivec3( minBlock / step );
        auto maxB = ivec3( maxBlock / step );
        auto arr = genRandomCCData( volume, minB, maxB, count );
        appendCCToList( arr, step, vec3( minPos, 0 ) );
    }

    CCData[] genRandomCCData( ivec3 volume, ivec3 minB, ivec3 maxB, size_t count, size_t attemptLim=10 )
    {
        if( count < 2 || volume.x < minB.x+1 ||
                         volume.y < minB.y+1 ||
                         volume.z < minB.z+1 )
            return [];

        CCData[] ret;

        foreach( i; 0 .. count )
        {
            CCData buf;
            size_t attempt;
            do
            {
                buf = genRandomCube( volume, minB, maxB );
                attempt++;
                if( attempt > attemptLim )
                    return ret;
            }
            while( intersect(buf,ret) );
            ret ~= buf;

            auto inner = genRandomCCData( ivec3( buf.size.xy, volume.z-buf.size.z ), minB, buf.size, 10 );

            auto h = ivec3( 0,0,buf.size.z );
            foreach( m; inner )
                ret ~= CCData( m.pos + buf.pos + h, m.size );
        }
        return ret;
    }

    CCData genRandomCube( ivec3 grid, ivec3 minB, ivec3 maxB )
    {
        import std.random;
        import std.algorithm;

        auto maxPos = grid - minB;

        auto pp = ivec3( uniform(0,maxPos.x),
                         uniform(0,maxPos.y), 0 );

        auto maxSz = grid - pp;
        auto sz = ivec3( uniform!"[]"( minB.x, min( maxSz.x, maxB.x ) ),
                         uniform!"[]"( minB.y, min( maxSz.y, maxB.y ) ),
                         uniform!"[]"( minB.z, min( maxSz.z, maxB.z ) ) );

        return CCData( pp, sz );
    }

    bool intersect( CCData obj, CCData[] other )
    {
        foreach( o; other )
            if( intersect(obj,o) || intersect(o,obj) )
                return true;
        return false;
    }

    bool intersect( CCData a, CCData b )
    {
        return a.has( b.pos ) ||
               a.has( b.pos + ivec3(b.size.x,0,0) ) ||
               a.has( b.pos + ivec3(0,b.size.y,0) ) ||
               a.has( b.pos + ivec3(0,0,b.size.z) ) ||
               a.has( b.pos + ivec3(b.size.x,b.size.y,0) ) ||
               a.has( b.pos + ivec3(0,b.size.y,b.size.z) ) ||
               a.has( b.pos + ivec3(b.size.x,0,b.size.z) ) ||
               a.has( b.pos + b.size );
    }

    void appendCCToList( CCData[] arr, vec3 step, vec3 offset )
    {
        auto mc = new MultiCube(null);
        foreach( c; arr )
            mc.addCube( vec3(c.pos)  * step + offset, vec3(c.size) * step );
        list ~= mc;
    }
}
