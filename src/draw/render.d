module draw.render;

import des.util.emm;

import des.math.linear;

import des.gl.base;

import des.il;

import std.stdio;

class Render : ExternalMemoryManager
{
    mixin( getMixinChildEMM );
protected:

    GLFrameBuffer fbo;
    Image!2 depth_img, color_img;
    GLTexture depth, color;

public:

    this()
    {
        depth = registerChildEMM( new GLTexture(GLTexture.Target.T2D) );
        color = registerChildEMM( new GLTexture(GLTexture.Target.T2D) );

        depth.setParameter( GLTexture.Parameter.WRAP_S, GLTexture.Wrap.CLAMP_TO_EDGE );
        depth.setParameter( GLTexture.Parameter.WRAP_T, GLTexture.Wrap.CLAMP_TO_EDGE );
        depth.setParameter( GLTexture.Parameter.MIN_FILTER, GLTexture.Filter.NEAREST );
        depth.setParameter( GLTexture.Parameter.MAG_FILTER, GLTexture.Filter.NEAREST );

        color.setParameter( GLTexture.Parameter.WRAP_S, GLTexture.Wrap.CLAMP_TO_EDGE );
        color.setParameter( GLTexture.Parameter.WRAP_T, GLTexture.Wrap.CLAMP_TO_EDGE );
        color.setParameter( GLTexture.Parameter.MIN_FILTER, GLTexture.Filter.NEAREST );
        color.setParameter( GLTexture.Parameter.MAG_FILTER, GLTexture.Filter.NEAREST );

        resize( ivec2(1,1) );

        fbo = registerChildEMM( new GLFrameBuffer );
        fbo.texture( depth, fbo.Attachment.DEPTH );
        fbo.texture( color, fbo.Attachment.COLOR0 );
        fbo.unbind();
    }

    void opCall( ivec2 sz, void delegate() draw_func )
    in
    {
        assert( sz.x > 0 );
        assert( sz.y > 0 );
        assert( draw_func !is null );
    }
    body
    {
        resize( sz );

        fbo.bind();

        glViewport( 0, 0, sz.x, sz.y );
        glEnable( GL_DEPTH_TEST );
        glDepthFunc( GL_LEQUAL );
        glDepthMask( true );
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

        draw_func();

        fbo.unbind();
    }

    void resize( ivec2 sz )
    {
        depth_img.size = sz;
        color_img.size = sz;
        depth.image( sz, GLTexture.InternalFormat.DEPTH_COMPONENT, GLTexture.Format.DEPTH, GLTexture.Type.FLOAT );
        color.image( sz, GLTexture.InternalFormat.RGBA, GLTexture.Format.RGBA, GLTexture.Type.FLOAT );
    }

    @property
    {
        ref Image!2 depthImage()
        {
            depth.getImage( depth_img, GLTexture.Format.DEPTH, GLTexture.Type.FLOAT );
            return depth_img;
        }

        ref Image!2 colorImage()
        {
            color.getImage( color_img, GLTexture.Format.RGB, GLTexture.Type.UNSIGNED_BYTE );
            return color_img;
        }
    }

    void bindDepthTexture( ubyte n=0 ) { depth.bind(n); }
    void unbindDepthTexture() { depth.unbind(); }

    void bindColorTexture( ubyte n=0 ) { color.bind(n); }
    void unbindColorTexture() { color.unbind(); }

    protected void selfDestroy()
    {
        fbo.unbind();
        depth.unbind();
        color.unbind();
    }
}
