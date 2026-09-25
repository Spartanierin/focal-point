// Deterministic extraction for ONE hash-pinned RGB master, not a general color key.
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public static class NavigatorBrandAsset
{
    const int Width = 1024, Height = 256;
    // 4:1 source canvas, uniform 1.875x area reduction. Keep the complete bevel.
    const int Left = 10, Top = 181, SourceWidth = 1920, SourceHeight = 480;

    static void Require(bool condition, string message)
    { if (!condition) throw new Exception(message); }

    static bool[] Silhouette(Bitmap master)
    {
        int w = master.Width, h = master.Height;
        int[] firstX = new int[h], lastX = new int[h], firstY = new int[w], lastY = new int[w];
        for (int y = 0; y < h; y++) { firstX[y] = w; lastX[y] = -1; }
        for (int x = 0; x < w; x++) { firstY[x] = h; lastY[x] = -1; }
        // Locate the dark outer outline only. Row AND column envelopes describe
        // this orthogonally convex plaque, including the four scooped corners.
        // Fill the enclosed silhouette irrespective of RGB: studs/highlights
        // are never keyed out. The pinned master has a bright exterior >160.
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            Color c = master.GetPixel(x, y);
            if (Math.Max(c.R, Math.Max(c.G, c.B)) >= 160) continue;
            firstX[y] = Math.Min(firstX[y], x); lastX[y] = Math.Max(lastX[y], x);
            firstY[x] = Math.Min(firstY[x], y); lastY[x] = Math.Max(lastY[x], y);
        }
        var mask = new bool[w * h];
        int minX = w, minY = h, maxX = -1, maxY = -1, count = 0;
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            if (x < firstX[y] || x > lastX[y] || y < firstY[x] || y > lastY[x]) continue;
            mask[y * w + x] = true; count++;
            minX = Math.Min(minX, x); minY = Math.Min(minY, y);
            maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
        }
        Require(minX >= 20 && minX <= 25 && maxX >= 1910 && maxX <= 1918
            && minY >= 182 && minY <= 186 && maxY >= 655 && maxY <= 660,
            "Unexpected silhouette bounds; review source, do not silently crop");
        Require(count > 850000 && count < 910000, "Unexpected silhouette area");
        Require(minX > Left && maxX < Left + SourceWidth - 1
            && minY > Top && maxY < Top + SourceHeight - 1, "Canvas clips bevel");
        // Interior rectangles cover four studs and both complete rivet rails,
        // including their lightest highlights. No material pixels may be lost.
        int[,] protectedRects = { {85,220,160,290}, {1778,220,1846,290},
            {85,547,160,610}, {1778,547,1846,610},
            {207,213,1726,257}, {207,586,1726,629}, {200,270,1740,570} };
        int highlights = 0;
        for (int r = 0; r < protectedRects.GetLength(0); r++)
            for (int y = protectedRects[r,1]; y <= protectedRects[r,3]; y++)
                for (int x = protectedRects[r,0]; x <= protectedRects[r,2]; x++)
                {
                    Require(mask[y*w+x], "Mask damaged a stud, rail or material interior");
                    Color c = master.GetPixel(x,y);
                    if (Math.Min(c.R, Math.Min(c.G,c.B)) > 200) highlights++;
                }
        Require(highlights > 100, "Missing protected bright metal highlights");
        Console.WriteLine("Silhouette: {0},{1}..{2},{3}; {4} pixels; protected highlights {5}",
            minX,minY,maxX,maxY,count,highlights);
        return mask;
    }

    static Bitmap Resample(Bitmap master, bool[] mask)
    {
        var result = new Bitmap(Width, Height, PixelFormat.Format32bppArgb);
        double scale = (double)SourceWidth / Width;
        int transparent = 0, partial = 0, opaque = 0;
        for (int y = 0; y < Height; y++) for (int x = 0; x < Width; x++)
        {
            double x0 = Left+x*scale, y0 = Top+y*scale, x1=x0+scale, y1=y0+scale;
            double a=0, red=0, green=0, blue=0;
            // Exact area integration in premultiplied alpha. Exterior checker
            // RGB never contributes to edge pixels, preventing a white matte.
            for (int sy=(int)y0; sy<Math.Ceiling(y1); sy++)
                for (int sx=(int)x0; sx<Math.Ceiling(x1); sx++)
                {
                    if (!mask[sy*master.Width+sx]) continue;
                    double weight=(Math.Min(x1,sx+1)-Math.Max(x0,sx))*(Math.Min(y1,sy+1)-Math.Max(y0,sy));
                    Color c=master.GetPixel(sx,sy);
                    a+=weight; red+=c.R*weight; green+=c.G*weight; blue+=c.B*weight;
                }
            int alpha=(int)Math.Round(255*a/(scale*scale));
            if (alpha==0) { result.SetPixel(x,y,Color.FromArgb(0,0,0,0)); transparent++; }
            else
            {
                result.SetPixel(x,y,Color.FromArgb(alpha,(int)Math.Round(red/a),(int)Math.Round(green/a),(int)Math.Round(blue/a)));
                if (alpha==255) opaque++; else partial++;
            }
        }
        Require(transparent>5000 && partial>500 && opaque>220000, "Invalid runtime alpha coverage");
        for(int x=0;x<Width;x++) Require(result.GetPixel(x,0).A==0 && result.GetPixel(x,Height-1).A==0,"Vertical padding missing");
        for(int y=0;y<Height;y++) Require(result.GetPixel(0,y).A==0 && result.GetPixel(Width-1,y).A==0,"Horizontal padding missing");
        Console.WriteLine("RGBA {0}x{1}: transparent={2}, antialiased={3}, opaque={4}", Width,Height,transparent,partial,opaque);
        return result;
    }

    static byte[] Tga(Bitmap bitmap)
    {
        using(var stream=new MemoryStream()) using(var writer=new BinaryWriter(stream))
        {
            writer.Write(new byte[] {0,0,2,0,0,0,0,0,0,0,0,0});
            writer.Write((ushort)Width); writer.Write((ushort)Height);
            writer.Write((byte)32); writer.Write((byte)0x28);
            for(int y=0;y<Height;y++) for(int x=0;x<Width;x++)
            { Color c=bitmap.GetPixel(x,y); writer.Write(c.B); writer.Write(c.G); writer.Write(c.R); writer.Write(c.A); }
            return stream.ToArray();
        }
    }

    public static void Build(string masterPath, string runtimePath, bool check, string previewPath)
    {
        using(var master=new Bitmap(masterPath))
        {
            Require(master.Width==1942 && master.Height==809, "Unexpected master size");
            using(var runtime=Resample(master,Silhouette(master)))
            {
                var bytes=Tga(runtime);
                if(check) Require(Convert.ToBase64String(bytes)==Convert.ToBase64String(File.ReadAllBytes(runtimePath)),"Non-reproducible runtime asset");
                else File.WriteAllBytes(runtimePath,bytes);
                if(!String.IsNullOrEmpty(previewPath))
                {
                    using(var preview=new Bitmap(1060,448)) using(var g=Graphics.FromImage(preview))
                    {
                        g.Clear(Color.FromArgb(35,30,26));
                        g.DrawImageUnscaled(runtime,18,12);
                        g.FillRectangle(Brushes.White,18,280,500,150);
                        g.DrawImage(runtime,new RectangleF(25,300,490,122.5f));
                        g.DrawImage(runtime,new RectangleF(600,300,245,61.25f));
                        preview.Save(previewPath,ImageFormat.Png);
                    }
                }
            }
        }
    }
}
