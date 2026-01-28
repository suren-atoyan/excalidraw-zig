const elements_mod = @import("elements.zig");
const ColorKind = elements_mod.ColorKind;
const FillStyle = elements_mod.FillStyle;
const StrokeWidth = elements_mod.StrokeWidth;

pub const ElementProps = struct {
    color: ColorKind = .black,
    fill_style: FillStyle = .none,
    stroke_width: StrokeWidth = .normal,
};

pub const color_options = [_]ColorKind{ .black, .red, .blue, .green, .orange, .white };
pub const fill_options = [_]FillStyle{ .none, .solid, .crosshatch };
pub const stroke_width_options = [_]StrokeWidth{ .thin, .normal, .bold };
