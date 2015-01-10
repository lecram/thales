local ffi = require "ffi"
ffi.cdef[[
typedef struct {
    double x, y;
} alt_endpt_t;
typedef struct {
    double x, y;
    bool on;
} alt_ctrpt_t;
typedef struct {
    alt_endpt_t a, b, c;
} alt_curve_t;
typedef struct {
    double dist;    /* distance from scanline origin */
    int sign;       /* 1 for off-on crossing, -1 for on-off */
} alt_cross_t;
typedef struct {
    unsigned int bulk;  /* current capacity */
    unsigned int count; /* current ocupation */
    size_t size;        /* item size in bytes */
    void *items;        /* actual array contents */
} alt_array_t;
typedef struct {
    int width, height;  /* image size in pixels */
    int x0, y0, x1, y1; /* dirty region boundaries */
    double diameter;    /* pen diameter */
    /* Arrays of arrays of alt_cross_t. */
    alt_array_t **hori, **vert, **extr;
    uint8_t *data;      /* width*height pixels in format 0xRRGGBBAA */
} alt_image_t;
typedef struct {
    double a, b, c, d, e, f;
} alt_matrix_t;

alt_array_t *alt_new_array(size_t item_size, unsigned int init_bulk);
void alt_resize_array(alt_array_t *array, unsigned int min_bulk);
void alt_push(alt_array_t *array, void *item);
void alt_pop(alt_array_t *array, void *item);
void alt_sort(alt_array_t *array, int (*comp)(const void *, const void *));
void alt_del_array(alt_array_t **array);
alt_array_t *alt_box_array(unsigned int item_count, size_t item_size, void *items);
void *alt_unbox_array(alt_array_t **array);

int alt_comp_cross(const void *a, const void *b);

uint32_t alt_pack_color(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void alt_unpack_color(uint32_t color, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a);
alt_image_t *alt_new_image(int width, int height);
alt_image_t *alt_open_pam(const char *fname);
void alt_set_line_width(alt_image_t *image, double line_width);
void alt_get_pixel(alt_image_t *image, int x, int y,
                   uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a);
void alt_set_pixel(alt_image_t *image, int x, int y,
                   uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void alt_clear(alt_image_t *image, uint32_t color);
void alt_blend(alt_image_t *image, int x, int y,
               uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void alt_save_pam(alt_image_t *image, const char *fname);
void alt_del_image(alt_image_t **image);

void alt_scan(alt_image_t *image, alt_endpt_t *pa, alt_endpt_t *pb);
void alt_scan_array(alt_image_t *image, alt_endpt_t *points, int count);
void alt_windredux(alt_image_t *image);

double alt_scanrange(alt_array_t *scanline, double x);
double alt_dist(alt_image_t *image, double x, double y, double r);

void alt_draw(alt_image_t *image, uint32_t fill, uint32_t strk);

void alt_add_curve(alt_array_t *endpts, alt_curve_t *curve);
alt_array_t *alt_unfold(alt_ctrpt_t *ctrpts, int count);
alt_ctrpt_t *alt_circle(double x, double y, double r);

void alt_reset(alt_matrix_t *mat);
void alt_add_custom(alt_matrix_t *mat, double a, double b,
                    double c, double d, double e, double f);
void alt_add_squeeze(alt_matrix_t *mat, double k);
void alt_add_scale(alt_matrix_t *mat, double x, double y);
void alt_add_hshear(alt_matrix_t *mat, double h);
void alt_add_vshear(alt_matrix_t *mat, double v);
void alt_add_rotate(alt_matrix_t *mat, double a);
void alt_add_translate(alt_matrix_t *mat, double x, double y);
void alt_transform_endpts(alt_endpt_t *endpts, int count, alt_matrix_t *mat);
void alt_transform_ctrpts(alt_ctrpt_t *ctrpts, int count, alt_matrix_t *mat);
]]
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

function AltImage:set_line_width(width)
    C.alt_set_line_width(self.img, width)
end

function AltImage:clear(color)
    C.alt_clear(self.img, color)
end

function AltImage:lines(end_points)
    local array, length = as_array(end_points, "alt_endpt_t")
    C.alt_scan_array(self.img, array, length)
end

function AltImage:curves(control_points)
    local array, length = as_array(control_points, "alt_ctrpt_t")
    array = C.alt_unfold(array, length)
    length = array.count
    array = C.alt_unbox_array(ffi.new("alt_array_t *[1]", array))
    C.alt_scan_array(self.img, array, length)
end

function AltImage:draw(fill, stroke)
    C.alt_draw(self.img, fill, stroke)
end

function AltImage:save(fname)
    C.alt_save_pam(self.img, fname)
end

return {Image=Image, open=open}
