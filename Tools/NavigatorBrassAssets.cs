// Narrow, deterministic build for the three Navigator runtime slices. No packages.
// Corner is canonical; independent edge masters are reference only. Never written.
using System;
using System.Drawing;
using System.IO;

public static class NavigatorBrassAssets
{
    const int CornerSize = 128;
    // Canonical source-coordinate map retained from the rescue. The tuning map
    // below redistributes this normalized 64-unit space into the runtime texture.
    static double X(double u) { return u <= 16 ? 30 + u * 350 / 16 : 380 + (u - 16) * 720 / 48; }
    // Slightly expand the thinner horizontal rail to match the vertical rail's
    // visible cross-section, while keeping the inner boundary at texel 16.
    static double Y(double v) { return v <= 16 ? 46 + 364 * Math.Pow(v / 16, .82) : 410 + (v - 16) * 690 / 48; }

    // Tuning: enlarge artwork, not the transparent master canvas. Allocate 40/128
    // texels to the ornament band (formerly 16/64), and crop quiet arms at source
    // coordinate ~920 instead of 1100. At 56 UI units this makes ornaments denser.
    static double Ornament(double t) { return t <= 40 ? t * 16 / 40 : 16 + (t - 40) * 36 / 88; }
    // Double the canonical rail cross-section, remove eight texels of outer pad:
    // ~16 visible texels = 7 UI units, ending about 10.5 UI units inside the bounds.
    static double Rail(double t) { return (t + 8) / 2; }
    static double Straighten(double t)
    {
        t = Math.Max(0, Math.Min(1, (t - 64) / 56));
        return t * t * (3 - 2 * t);
    }
    static double Blend(double a, double b, double t) { return a + (b - a) * t; }

    static Color Sample(Bitmap master, int x, int y, int kind)
    {
        // One canonical cross-section for BOTH axes; no new edge ornament.
        if (kind == 2) return Sample(master, y, x, 1);
        double alpha = 0, red = 0, green = 0, blue = 0;
        // 16x16 area sampling in premultiplied alpha: preserve fine rails without
        // importing transparent RGB/matte into downsampled edges.
        for (int j = 0; j < 16; j++) for (int i = 0; i < 16; i++)
        {
            double u = x + (i + .5) / 16, v = y + (j + .5) / 16;
            double sx = X(Blend(Ornament(u), Rail(u), Straighten(v)));
            double sy = Y(Blend(Ornament(v), Rail(v), Straighten(u)));
            if (kind == 1)
            {
                if (Rail(v) >= 64) continue;
                sx = X(63 + (i + .5) / 16) - 150 * Math.Pow(Math.Sin(Math.PI * x / 255), 2);
                sy = Y(Rail(v));
            }
            Color c = master.GetPixel((int)sx, (int)sy);
            int a = c.A < 16 ? 0 : c.A; // Remove the masters' barely visible stray alpha.
            alpha += a; red += c.R * a; green += c.G * a; blue += c.B * a;
        }
        if (alpha < 128) return Color.FromArgb(0, 0, 0, 0);
        return Color.FromArgb((int)Math.Round(alpha / 256), (int)Math.Round(red / alpha),
            (int)Math.Round(green / alpha), (int)Math.Round(blue / alpha));
    }

    static Color Mix(Color a, Color b, double t)
    {
        double aa = a.A * (1 - t), ba = b.A * t, alpha = aa + ba;
        if (alpha < .5) return Color.FromArgb(0, 0, 0, 0);
        return Color.FromArgb((int)Math.Round(alpha), (int)Math.Round((a.R * aa + b.R * ba) / alpha),
            (int)Math.Round((a.G * aa + b.G * ba) / alpha), (int)Math.Round((a.B * aa + b.B * ba) / alpha));
    }

    static Bitmap Make(Bitmap master, int width, int height, int kind)
    {
        var result = new Bitmap(width, height);
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
            result.SetPixel(x, y, Sample(master, x, y, kind));
        return result;
    }

    static byte[] Tga(Bitmap bitmap)
    {
        using (var stream = new MemoryStream()) using (var writer = new BinaryWriter(stream))
        {
            writer.Write(new byte[] { 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
            writer.Write((ushort)bitmap.Width); writer.Write((ushort)bitmap.Height);
            writer.Write((byte)32); writer.Write((byte)0x28); // top-left origin, 8 alpha bits
            for (int y = 0; y < bitmap.Height; y++) for (int x = 0; x < bitmap.Width; x++)
            {
                Color c = bitmap.GetPixel(x, y);
                writer.Write(c.B); writer.Write(c.G); writer.Write(c.R); writer.Write(c.A);
            }
            return stream.ToArray();
        }
    }

    static void Save(string path, Bitmap bitmap, bool check)
    {
        var bytes = Tga(bitmap);
        if (check)
        {
            var existing = File.ReadAllBytes(path);
            if (Convert.ToBase64String(bytes) != Convert.ToBase64String(existing))
                throw new Exception("Runtime output differs: " + path);
        }
        else File.WriteAllBytes(path, bytes);
        bool transparent = false, visible = false;
        for (int y = 0; y < bitmap.Height; y++) for (int x = 0; x < bitmap.Width; x++)
        { int a = bitmap.GetPixel(x, y).A; transparent |= a == 0; visible |= a >= 128; }
        if (!transparent || !visible) throw new Exception("Invalid alpha: " + path);
    }

    static void Equal(Color a, Color b)
    { if (a.ToArgb() != b.ToArgb()) throw new Exception("Corner/tile seam mismatch"); }

    public static void Build(string root, bool check, string previewPath)
    {
        using (var master = new Bitmap(Path.Combine(root, "fp_navigator_corner_Master_1254x1254.png")))
        using (var corner = Make(master, CornerSize, CornerSize, 0))
        using (var horizontal = Make(master, 256, CornerSize, 1))
        using (var vertical = Make(master, CornerSize, 256, 2))
        {
            // Lock cross-section/alpha to the canonical endpoint. Low-amplitude
            // longitudinal detail comes from its adjacent arm, with a smooth periodic
            // traversal (no endcap). This also keeps arbitrary partial tiles quiet.
            for (int y = 0; y < CornerSize; y++) for (int x = 0; x < 256; x++)
            {
                Color basis = horizontal.GetPixel(0, y), detail = horizontal.GetPixel(x, y);
                double amount = .18 * Math.Pow(Math.Sin(Math.PI * x / 255), 2);
                Color mixed = Mix(basis, detail, amount);
                horizontal.SetPixel(x, y, Color.FromArgb(basis.A, mixed.R, mixed.G, mixed.B));
                detail = vertical.GetPixel(y, x);
                mixed = Mix(basis, detail, amount);
                vertical.SetPixel(y, x, Color.FromArgb(basis.A, mixed.R, mixed.G, mixed.B));
            }
            // Feather the last 8 corner texels to the same constant endpoint profile.
            for (int i = CornerSize - 8; i < CornerSize; i++) for (int cross = 0; cross < CornerSize; cross++)
            {
                double t = (i - (CornerSize - 8)) / 7.0; t = t * t * (3 - 2 * t);
                corner.SetPixel(i, cross, Mix(corner.GetPixel(i, cross), horizontal.GetPixel(0, cross), t));
                corner.SetPixel(cross, i, Mix(corner.GetPixel(cross, i), vertical.GetPixel(cross, 0), t));
            }
            for (int i = 0; i < CornerSize; i++)
            {
                Equal(horizontal.GetPixel(0, i), horizontal.GetPixel(255, i));
                Equal(vertical.GetPixel(i, 0), vertical.GetPixel(i, 255));
                Equal(corner.GetPixel(CornerSize - 1, i), horizontal.GetPixel(0, i));
                Equal(corner.GetPixel(i, CornerSize - 1), vertical.GetPixel(i, 0));
                for (int along = 0; along < 256; along++)
                    Equal(horizontal.GetPixel(along, i), vertical.GetPixel(i, along));
            }
            foreach (int threshold in new int[] { 16, 128 })
            {
                int hWidth = 0, vWidth = 0;
                for (int i = 0; i < CornerSize; i++)
                {
                    if (horizontal.GetPixel(0, i).A >= threshold) hWidth++;
                    if (vertical.GetPixel(i, 0).A >= threshold) vWidth++;
                }
                if (hWidth != vWidth || hWidth * 56.0 / CornerSize < 6 || hWidth * 56.0 / CornerSize > 8)
                    throw new Exception("Rail widths differ or are outside the 6-8 UI unit budget");
                Console.WriteLine("Rail alpha >= {0}: {1} texels / {2:F3} UI units", threshold, hWidth, hWidth * 56.0 / CornerSize);
            }
            Save(Path.Combine(root, "fp_navigator_brass_corner.tga"), corner, check);
            Save(Path.Combine(root, "fp_navigator_brass_horizontal.tga"), horizontal, check);
            Save(Path.Combine(root, "fp_navigator_brass_vertical.tga"), vertical, check);
            if (!String.IsNullOrEmpty(previewPath)) Preview(previewPath, corner, horizontal, vertical);
        }
    }

    static void Preview(string path, Bitmap corner, Bitmap horizontal, Bitmap vertical)
    {
        // Native-texel proof sheet at 128/56 texels per UI unit.
        using (var sheet = new Bitmap(1415, 760))
        using (var g = Graphics.FromImage(sheet))
        {
            g.Clear(Color.FromArgb(35, 30, 30));
            foreach (int width in new int[] { 651, 720 })
            {
                int left = width == 651 ? 10 : 685, top = 10, height = 730;
                for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
                {
                    Color c = Color.Transparent;
                    int xx = x < width / 2 ? x : width - 1 - x;
                    int yy = y < height / 2 ? y : height - 1 - y;
                    if (xx < CornerSize && yy < CornerSize) c = corner.GetPixel(xx, yy);
                    else if (y < CornerSize || y >= height - CornerSize) c = horizontal.GetPixel((x - CornerSize) % 256, yy);
                    else if (x < CornerSize || x >= width - CornerSize) c = vertical.GetPixel(xx, (y - CornerSize) % 256);
                    if (c.A > 0) sheet.SetPixel(left + x, top + y, Mix(sheet.GetPixel(left + x, top + y), Color.FromArgb(255, c.R, c.G, c.B), c.A / 255.0));
                }
            }
            sheet.Save(path, System.Drawing.Imaging.ImageFormat.Png);
        }
    }
}
