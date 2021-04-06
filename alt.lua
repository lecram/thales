local ffi = require "ffi"
ffi.cdef[[
typedef struct {
    double x, y;
} AltEndPt;
typedef struct {
    double x, y;
    bool on;
} AltCtrPt;
typedef struct {
    AltEndPt a, b, c;
} AltCurve;
typedef struct {
    double dist;    /* distance from scanline origin */
    int sign;       /* 1 for off-on crossing, -1 for on-off */
} AltCross;
typedef struct {
    unsigned int bulk;  /* current capacity */
    unsigned int count; /* current ocupation */
    size_t size;        /* item size in bytes */
    void *items;        /* actual array contents */
} AltArray;
typedef struct {
    int width, height;  /* image size in pixels */
    int x0, y0, x1, y1; /* dirty region boundaries */
    double diameter;    /* pen diameter */
    /* Arrays of arrays of AltCross. */
    AltArray **hori, **vert, **extr;
    uint8_t *data;      /* width*height pixels in format 0xRRGGBBAA */
} AltImage;
typedef struct {
    double a, b, c, d, e, f;
} AltMatrix;

AltArray *alt_new_array(size_t item_size, unsigned int init_bulk);
void alt_resize_array(AltArray *array, unsigned int min_bulk);
void alt_push(AltArray *array, void *item);
void alt_pop(AltArray *array, void *item);
void alt_sort(AltArray *array, int (*comp)(const void *, const void *));
void alt_del_array(AltArray **array);
AltArray *alt_box_array(unsigned int item_count, size_t item_size, void *items);
void *alt_unbox_array(AltArray **array);

int alt_comp_cross(const void *a, const void *b);

uint32_t alt_pack_color(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void alt_unpack_color(uint32_t color, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a);
AltImage *alt_new_image(int width, int height);
AltImage *alt_open_pam(const char *fname);
double alt_get_diameter(AltImage *image);
void alt_set_diameter(AltImage *image, double diameter);
void alt_get_pixel(AltImage *image, int x, int y,
                   uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a);
void alt_set_pixel(AltImage *image, int x, int y,
                   uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void alt_clear(AltImage *image, uint32_t color);
void alt_blend(AltImage *image, int x, int y,
               uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void alt_save_pam(AltImage *image, const char *fname);
void alt_del_image(AltImage **image);

void alt_scan(AltImage *image, AltEndPt *pa, AltEndPt *pb);
void alt_scan_array(AltImage *image, AltEndPt *points, int count);
void alt_windredux(AltImage *image);

static double alt_scanrange(AltArray *scanline, double x);
static double alt_dist(AltImage *image, double x, double y, double r);

void alt_draw(AltImage *image, uint32_t fill, uint32_t strk);

void alt_add_curve(AltArray *endpts, AltCurve *curve);
AltArray *alt_unfold(AltCtrPt *ctrpts, int count);
AltCtrPt *alt_circle(double x, double y, double r);

void alt_reset(AltMatrix *mat);
void alt_add_custom(AltMatrix *mat, double a, double b,
                    double c, double d, double e, double f);
void alt_add_squeeze(AltMatrix *mat, double k);
void alt_add_scale(AltMatrix *mat, double x, double y);
void alt_add_hshear(AltMatrix *mat, double h);
void alt_add_vshear(AltMatrix *mat, double v);
void alt_add_rotate(AltMatrix *mat, double a);
void alt_add_translate(AltMatrix *mat, double x, double y);
void alt_transform_endpts(AltEndPt *endpts, int count, AltMatrix *mat);
void alt_transform_ctrpts(AltCtrPt *ctrpts, int count, AltMatrix *mat);]]
local C = ffi.load("./libalt.so")

local function as_array(data, ctype)
    local array
    local length
    if type(data) == "cdata" then
        -- assume C array
        array = data
        length = ffi.sizeof(data) / ffi.sizeof(ctype)
    else
        -- assume Lua table
        length = #data
        array = ffi.new(ctype.."["..length.."]", data)
    end
    return array, length
end

local AltImage = {}
AltImage.__index = AltImage

local function Image(width, height)
    local img = C.alt_new_image(width, height)
    if img == nil then
        return nil
    else
        local tab = {img=img, width=img.width, height=img.height}
        return setmetatable(tab, AltImage)
    end
end

local function open(fname)
    local img = C.alt_open_pam(fname)
    if img == nil then
        return nil
    else
        local tab = {img=img, width=img.width, height=img.height}
        return setmetatable(tab, AltImage)
    end
end

function AltImage:get_diameter()
    return C.alt_get_diameter(self.img)
end

function AltImage:set_diameter(diameter)
    C.alt_set_diameter(self.img, diameter)
end

function AltImage:clear(color)
    C.alt_clear(self.img, color)
end

function AltImage:lines(end_points)
    local array, length = as_array(end_points, "AltEndPt")
    C.alt_scan_array(self.img, array, length)
end

function AltImage:curves(control_points)
    local array, length = as_array(control_points, "AltCtrPt")
    array = C.alt_unfold(array, length)
    length = array.count
    array = C.alt_unbox_array(ffi.new("AltArray *[1]", array))
    C.alt_scan_array(self.img, array, length)
end

function AltImage:draw(fill, stroke)
    C.alt_draw(self.img, fill, stroke)
end

function AltImage:save(fname)
    C.alt_save_pam(self.img, fname)
end

return {Image=Image, open=open}
