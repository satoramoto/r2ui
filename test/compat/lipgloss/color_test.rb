# frozen_string_literal: true

require "minitest/autorun"
$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)
require "r2ui/compat/lipgloss"
require "io/console"
require "pty"

# Every expected value below was recorded from the real lipgloss gem 0.2.2 (arm64-darwin, Go lipgloss
# v1.1.0): blends by calling Lipgloss::ColorBlend directly, escape sequences by rendering
# `Lipgloss::Style.new.foreground(c)` / `.background(c)` / `.bold(true).foreground(c).background(c)`
# on "x" in a child process under a pty (or a pipe) with the stated environment, answering the
# terminal's OSC 11 query with a dark or light background.
class CompatLipglossColorTest < Minitest::Test
  Gloss = R2UI::Compat::Gloss
  Termenv = Gloss::Termenv
  Renderer = Gloss::Renderer
  LIB = File.expand_path("../../../lib", __dir__)

  # [c1, c2, t, blend_luv, blend_rgb, blend_hcl]
  RECORDED_BLENDS = [
    ["#f8ca60", "#597624", 1.679142114632255, "#6d43fb", "#ee3dfc", "#003b0d"],
    ["#90013c", "#ed3142", 0.4738457034082185, "#bb1b40", "#bc183f", "#bd1542"],
    ["#e4316f", "#a6e", 1.0, "#aa66ee", "#aa66ee", "#aa66ee"],
    ["#b26b49", "#908af4", 1.2072997773557401, "#799115", "#899017", "#00a0ff"],
    ["#757356", "#83ba9d", 0.3, "#7b886b", "#79886b", "#7d8866"],
    ["#ac4a39", "#939bfe", 0.7167890919946702, "#a883cb", "#9a84c6", "#c077cc"],
    ["#d6d75a", "#8236b0", 0.23898683243572905, "#beb47f", "#c2b16f", "#f4a140"],
    ["#2f97b7", "#a0fdcd", 0.875, "#94f0cb", "#92f0ca", "#89f1cd"],
    ["#524130", "#8b8d3f", 1.125, "#939741", "#929741", "#8e9843"],
    ["#79fce8", "#56b", 0.8, "#5b85c2", "#5c84c4", "#1c88d7"],
    ["#8408b5", "#96e18c", 0.7, "#8daf9c", "#91a098", "#00c3bf"],
    ["#24ceb2", "#d86d7a", -0.11432704931456517, "#ced8b8", "#0fd9b8", "#00d4d3"],
    ["#1faa57", "#e61968", 0.4, "#a0845f", "#6f705e", "#9f8800"],
    ["#18c87b", "#b66003", 0.75, "#ab7b34", "#8f7a21", "#a57f00"],
    ["#4d4", "#cb99b0", 1.4725919079963874, "#f166d0", "#0b79e3", "#a09b8a"],
    ["#56c9fc", "#1a8253", 0.4166666666666667, "#3dabb7", "#3dabb6", "#00afbd"],
    ["#8a0", "#8b1ced", 1.5465401584252558, "#479d6c", "#8dcf6f", "#0066dc"],
    ["#e7440c", "#246bd8", 0.8888888888888888, "#6765c7", "#3a67c1", "#6961d4"],
    ["#63d28b", "#a48d9d", 0.5, "#8cb195", "#84b094", "#d39d73"],
    ["#635ea3", "#b7d12f", 0.8311488567392082, "#a8be5d", "#a9be43", "#e3ab25"],
    ["#c2f4be", "#cbf2aa", 1.0, "#cbf2aa", "#cbf2aa", "#cbf2aa"],
    ["#690ed9", "#092", 0.8709586206567291, "#1d8f4d", "#0e873a", "#00974e"],
    ["#d8a1d1", "#59b", 0.8, "#799bbf", "#6f9bbf", "#6c9cc8"],
    ["#96464d", "#59b", 1.9588314312227624, "#41e922", "#17e924", "#c3c7a6"],
    ["#19439d", "#c5b742", 0.8, "#a99f65", "#a3a054", "#dd8b3c"],
    ["#ee3c1e", "#d130f1", 0.29015381999405976, "#e93a76", "#e6395b", "#ff0055"],
    ["#460", "#47ecd3", 1.588597055829351, "#bc433e", "#493b4f", "#92ffff"],
    ["#78f03b", "#cb9653", 1.8338773653585112, "#de2d58", "#104b67", "#7a7575"],
    ["#f8ae87", "#650e25", 0.22931455992854333, "#d38a6e", "#d68971", "#d7886d"],
    ["#3d9c17", "#9dec12", 1.651999061900323, "#d82300", "#dc200f", "#e5ff00"],
    ["#12c", "#f280af", 1.0, "#f280af", "#f280af", "#f280af"],
    ["#bc88d7", "#859970", 0.8, "#909787", "#909685", "#a39461"],
    ["#2cfc57", "#d2d754", 0.24381008854697672, "#76f356", "#54f356", "#7af34a"],
    ["#27780c", "#cecbbb", 0.9, "#bfc3ac", "#bdc3aa", "#c4c1a7"],
    ["#547", "#fd2ccd", 1.0577797932560777, "#0627d2", "#072bd2", "#ff21cf"],
    ["#f12", "#0ab9c5", 1.0, "#0ab9c5", "#0ab9c5", "#0ab9c5"],
    ["#93555d", "#d95ea6", 0.573585438213087, "#bb5b87", "#bb5a87", "#bf5980"],
    ["#2c56a3", "#407", 0.39114650445725196, "#373e8e", "#353492", "#323d96"],
    ["#fb5", "#8131ad", 1.8262603544648703, "#080ed0", "#19c0f6", "#002952"],
    ["#9fab5b", "#78edbf", 0.9, "#7fe6b6", "#7ce6b5", "#7de7b3"],
    ["#f06e1d", "#039", 0.8380621074973931, "#593a86", "#273d85", "#6a2997"],
    ["#f151d0", "#c96", 0.7272727272727273, "#d58b89", "#d68583", "#e78464"],
    ["#da1b1e", "#d1c", -0.07287177280335544, "#d91bdb", "#da1c11", "#d32810"],
    ["#71efdb", "#2f14b3", 0.8434558264524068, "#334aa6", "#3936b9", "#004fd9"],
    ["#0da7b7", "#cf1e0e", 0.9843738591690412, "#cf2217", "#cc2011", "#cc2805"],
    ["#e7cc1a", "#a20f51", 0.5122482088831739, "#c37a4b", "#c46b36", "#e46533"],
    ["#967a54", "#894999", 0.6645111292535977, "#8c5c85", "#8d5982", "#ac4b6d"],
    ["#4591b7", "#d48ca5", 1.6003504152870787, "#088896", "#2a899a", "#daa47d"],
    ["#9c82d9", "#620504", 0.3333333333333333, "#8f5a98", "#895892", "#a44e91"],
    ["#32f0e7", "#6d0", 0.29213589127474315, "#4bebbe", "#41eaa4", "#00efc1"],
    ["#ada", "#5b0b87", 0.3, "#8ca59d", "#929ea0", "#00b5b3"],
    ["#4e1781", "#802261", 0.8, "#782066", "#762067", "#7a1c66"],
    ["#74fb5a", "#edc750", 0.8571428571428571, "#e2cf51", "#dcce51", "#e5ce49"],
    ["#3dac0f", "#1d07c5", 0.5, "#297178", "#2d5a6a", "#0085cc"],
    ["#1d8a6e", "#4ebcf9", 0.1900776982619985, "#27948a", "#269488", "#00968a"],
    ["#c2d", "#d82d30", 0.7142857142857143, "#d72b70", "#d52a61", "#eb0058"],
    ["#6ae5b9", "#c8c275", 0.9958623608551391, "#c8c275", "#c8c275", "#c8c275"],
    ["#d8b67a", "#f12647", 0.8489558726678508, "#f1484f", "#ed3c4f", "#ef4c42"],
    ["#262", "#361ae5", 0.9336336195203927, "#332ed2", "#351fd8", "#003ef3"],
    ["#595a7c", "#e0d061", 0.025628955006142595, "#5d5d7c", "#5c5d7b", "#5f5c7f"],
    ["#ebb", "#9fbaba", 2.0, "#2cb8b8", "#50b9b9", "#a2a3a3"],
    ["#20eedb", "#8a1a96", 0.05381209993542724, "#3ae4d7", "#26e3d7", "#00e7e0"],
    ["#1a4cb9", "#17d", 0.2727272727272727, "#1858c2", "#1858c3", "#1558c3"],
    ["#40653d", "#73f423", 0.1, "#45723e", "#45733a", "#43733f"],
    ["#506dbf", "#322ad2", -0.8840855077415861, "#6b99c2", "#6ba8ae", "#929499"],
    ["#f0a883", "#65be4a", 0.5132061554182594, "#b5b568", "#a9b366", "#c6b14c"],
    ["#a6d", "#7e4943", 0.3555878684992835, "#9b5ca8", "#9a5ca6", "#b84c92"],
    ["#8e4", "#b98662", 0.6, "#aeb15b", "#a5b056", "#caa845"],
    ["#d44c6f", "#ddcc61", 0.5149272597619592, "#db936c", "#d98e68", "#ec8b52"],
    ["#7d0438", "#33b29e", 0.09748939692705094, "#7e2541", "#761542", "#861e2c"],
    ["#b2c5c2", "#157", 0.8551381296458597, "#356480", "#286582", "#296581"],
    ["#31c7e5", "#fd6839", 0.012544492626768933, "#3fc6e3", "#34c6e3", "#29c7e3"],
    ["#4e8c50", "#cdc29f", 0.4327840633554262, "#89a372", "#85a372", "#8fa269"],
    ["#283400", "#136", 0.3031492089731527, "#25342d", "#21341f", "#003b26"],
    ["#168", "#d51d9e", -0.10299120843335718, "#6a6986", "#fe6e86", "#24647b"],
    ["#477f23", "#0f4", 0.5, "#3fbd33", "#24bf34", "#48bd2e"],
    ["#1626bb", "#8d1909", 0.4878495666176105, "#751d6c", "#502064", "#9e0059"],
    ["#132", "#69fd6c", -0.06325868108621446, "#0d281f", "#0b261d", "#0f281c"],
    ["#4c2168", "#9b8635", 0.08333333333333333, "#512d63", "#532964", "#621f64"],
    ["#b81cfd", "#8b289c", 0.75, "#9627b4", "#9625b4", "#9825b3"],
    ["#aa0ad3", "#2fcf2c", 0.7752621649395598, "#5db470", "#4ba352", "#b0a500"],
    # rounding ties that only come out right with arm64's fused multiply-add
    ["#59fd1a", "#7d300a", 0.9, "#81470c", "#79450c", "#8c4000"],
    ["#326821", "#c37c98", 0.9, "#b67b8e", "#b57a8c", "#c37585"]
  ].freeze

  # [c1, c2, steps, mode, blends]
  RECORDED_STEPS = [
    ["#76d02a", "#0ba", 9, :luv, ["#76d02a", "#6fcd4b", "#67cb60", "#5fc870", "#55c57e", "#4ac38b", "#3cc096", "#2abea0", "#00bbaa"]],
    ["#571ca5", "#e3a", 5, :rgb, ["#571ca5", "#7d22a6", "#a328a8", "#c82da9", "#ee33aa"]],
    ["#13a456", "#ac2917", 11, :hcl, ["#13a456", "#3f9c3d", "#579325", "#698a03", "#788000", "#857500", "#906900", "#9a5c00", "#a24d00", "#a83d02", "#ac2917"]],
    ["#e70cef", "#640cf5", 2, :luv, ["#e70cef", "#640cf5"]],
    ["#6f18bd", "#4e2618", 3, :rgb, ["#6f18bd", "#5f1f6b", "#4e2618"]],
    ["#def449", "#323265", 6, :hcl, ["#def449", "#ffb339", "#f67757", "#c94e71", "#823e79", "#323265"]],
    ["#00e0c7", "#d4175a", 10, :luv, ["#00e0c7", "#6acebb", "#8ebcae", "#a4aaa2", "#b59796", "#c0848a", "#c9707e", "#ce5a72", "#d24066", "#d4175a"]],
    ["#260", "#53f", 4, :rgb, ["#226600", "#335555", "#4444aa", "#5533ff"]],
    ["#2e37f5", "#b91", 11, :hcl, ["#2e37f5", "#9900d8", "#c900b6", "#e50094", "#f40073", "#f80055", "#f52f3b", "#eb5524", "#dd700b", "#cd8700", "#bb9911"]],
    ["#352164", "#c09", 10, :luv, ["#352164", "#4c1f68", "#5e1e6d", "#6f1c72", "#7f1a78", "#8f187e", "#9e1585", "#ad108b", "#bd0992", "#cc0099"]],
    ["#ed99ec", "#fcbc68", 4, :rgb, ["#ed99ec", "#f2a5c0", "#f7b094", "#fcbc68"]],
    ["#5610b1", "#daa", 5, :hcl, ["#5610b1", "#a0229e", "#c54e92", "#d77d95", "#ddaaaa"]],
    ["#df9e05", "#46f", 9, :luv, ["#df9e05", "#d2975a", "#c5917c", "#b88a95", "#a983ab", "#997cbf", "#8575d3", "#6c6ee7", "#4466ff"]],
    ["#7c2", "#fd0295", 2, :rgb, ["#77cc22", "#fd0295"]],
    ["#d4112f", "#df71bb", 3, :hcl, ["#d4112f", "#e6407b", "#df71bb"]],
    ["#36a0e4", "#8de007", 8, :luv, ["#36a0e4", "#4aaad3", "#59b3c2", "#65bcaf", "#70c59a", "#7ace81", "#84d75e", "#8de007"]],
    ["#44fc1a", "#549630", 7, :rgb, ["#44fc1a", "#47eb1e", "#49da21", "#4cc925", "#4fb829", "#51a72c", "#549630"]],
    ["#0f7f70", "#88f", 6, :hcl, ["#0f7f70", "#008991", "#0090b8", "#0094dd", "#0092f7", "#8888ff"]],
    ["#d76558", "#5b2581", 4, :luv, ["#d76558", "#ae5069", "#863c74", "#5b2581"]],
    ["#816", "#7d5fe3", 11, :rgb, ["#881166", "#871973", "#86217f", "#85288b", "#843098", "#8338a4", "#8140b1", "#8048bd", "#7f4fca", "#7e57d7", "#7d5fe3"]],
    ["#1f17ef", "#6a4", 10, :hcl, ["#1f17ef", "#0054ff", "#006eff", "#007fff", "#008ae4", "#0094bd", "#009c94", "#00a270", "#00a754", "#66aa44"]],
    ["#18e342", "#184c21", 8, :luv, ["#18e342", "#1bcc3d", "#1cb539", "#1c9f34", "#1c892f", "#1b742a", "#1a6026", "#184c21"]],
    ["#7b941f", "#b70", 7, :rgb, ["#7b941f", "#868f1a", "#908a15", "#9b8510", "#a6810a", "#b07c05", "#bb7700"]],
    ["#6df9d6", "#b29863", 9, :hcl, ["#6df9d6", "#7feebe", "#8ee2a8", "#9ad695", "#a3c985", "#aabd78", "#afb06e", "#b1a467", "#b29863"]]
  ].freeze

  # [corners, x_steps, y_steps, mode, grid]
  RECORDED_GRIDS = [
    [["#e33c34", "#860a88", "#b59391", "#025"], 2, 2, :luv, [["#e33c34", "#b52868"], ["#d46c68", "#93456a"]]],
    [["#087ba3", "#6df313", "#abe", "#ef205e"], 3, 2, :rgb, [["#087ba3", "#2aa373", "#4bcb43"], ["#599bc9", "#759599", "#928f69"]]],
    [["#271c28", "#23a", "#41f19d", "#3869c8"], 2, 3, :hcl, [["#271c28", "#402260"], ["#275985", "#0053a1"], ["#00a8bf", "#0085cc"]]],
    [["#1bdcd9", "#76c", "#6b19c6", "#a2c064"], 3, 1, :luv, [["#1bdcd9", "#52b7d4", "#6890cf"]]],
    [["#d7dbcf", "#6d4b42", "#63e9f2", "#de2909"], 1, 3, :rgb, [["#d7dbcf"], ["#b0e0db"], ["#8ae4e6"]]],
    [["#2fe4ea", "#2e28bc", "#d9a", "#03ce78"], 4, 3, :hcl,
     [["#2fe4ea", "#00bff1", "#0096f5", "#0067e7"], ["#75cbff", "#51b9fd", "#2da5fb", "#0190f6"], ["#c7ace6", "#a0adeb", "#72aee6", "#40add8"]]],
    [["#a20494", "#93b2ce", "#9a2", "#103"], 1, 3, :luv, [["#a20494"], ["#9c5c7d"], ["#9a8562"]]],
    [["#33aaec", "#ec6", "#cc678f", "#d792a2"], 4, 3, :rgb,
     [["#33aaec", "#62b3cb", "#91bba9", "#bfc488"], ["#6694cd", "#869db8", "#a6a6a4", "#c6af8f"], ["#997dae", "#aa87a6", "#bc919e", "#cd9b96"]]],
    [["#53d20c", "#91aa6b", "#f0e15d", "#eab3d5"], 3, 1, :hcl, [["#53d20c", "#73c438", "#86b753"]]],
    [["#f00", "#0f0", "#00f", "#fff"], 3, 2, :luv, [["#ff0000", "#ec8200", "#bfc300"], ["#be0090", "#c17b9a", "#bdc0a5"]]],
    [["#f00", "#0f0", "#00f", "#fff"], 2, 2, :hcl, [["#ff0000", "#d7a600"], ["#fb0080", "#ff895c"]]]
  ].freeze

  COMPOSITE = {
    adapt_hex: Lipgloss::AdaptiveColor.new(light: "#0000ff", dark: "#ff0000"),
    adapt_ansi: Lipgloss::AdaptiveColor.new(light: "1", dark: "2"),
    complete: Lipgloss::CompleteColor.new(true_color: "#123456", ansi256: 200, ansi: :red),
    complete_adapt: Lipgloss::CompleteAdaptiveColor.new(
      light: Lipgloss::CompleteColor.new(true_color: "#aabbcc", ansi256: "100", ansi: "3"),
      dark: Lipgloss::CompleteColor.new(true_color: "#332211", ansi256: "60", ansi: "12")
    )
  }.freeze

  # [color, foreground "x", background "x", bold + foreground + background "x" (when recorded)]
  RECORDED_SGR = {
    # pty, COLORTERM=truecolor TERM=xterm-256color, dark OSC 11 reply
    [:true_color, true] => [
      ["#ff8000", "\e[38;2;255;128;0mx\e[0m", "\e[48;2;255;128;0mx\e[0m", "\e[1;38;2;255;128;0;48;2;255;128;0mx\e[0m"],
      ["#f80", "\e[38;2;255;136;0mx\e[0m", "\e[48;2;255;136;0mx\e[0m", "\e[1;38;2;255;136;0;48;2;255;136;0mx\e[0m"],
      ["#FF8000", "\e[38;2;255;128;0mx\e[0m", "\e[48;2;255;128;0mx\e[0m", "\e[1;38;2;255;128;0;48;2;255;128;0mx\e[0m"],
      ["#zzz", "x", "x", "\e[1mx\e[0m"],
      ["#12345", "\e[38;2;18;52;5mx\e[0m", "\e[48;2;18;52;5mx\e[0m", "\e[1;38;2;18;52;5;48;2;18;52;5mx\e[0m"],
      ["#000000", "\e[38;2;0;0;0mx\e[0m", "\e[48;2;0;0;0mx\e[0m", "\e[1;38;2;0;0;0;48;2;0;0;0mx\e[0m"],
      ["#ffffff", "\e[38;2;255;255;255mx\e[0m", "\e[48;2;255;255;255mx\e[0m", "\e[1;38;2;255;255;255;48;2;255;255;255mx\e[0m"],
      ["#808080", "\e[38;2;128;128;128mx\e[0m", "\e[48;2;128;128;128mx\e[0m", "\e[1;38;2;128;128;128;48;2;128;128;128mx\e[0m"],
      ["0", "\e[30mx\e[0m", "\e[40mx\e[0m", "\e[1;30;40mx\e[0m"],
      ["1", "\e[31mx\e[0m", "\e[41mx\e[0m", "\e[1;31;41mx\e[0m"],
      ["7", "\e[37mx\e[0m", "\e[47mx\e[0m", "\e[1;37;47mx\e[0m"],
      ["8", "\e[90mx\e[0m", "\e[100mx\e[0m", "\e[1;90;100mx\e[0m"],
      ["9", "\e[91mx\e[0m", "\e[101mx\e[0m", "\e[1;91;101mx\e[0m"],
      ["15", "\e[97mx\e[0m", "\e[107mx\e[0m", "\e[1;97;107mx\e[0m"],
      ["16", "\e[38;5;16mx\e[0m", "\e[48;5;16mx\e[0m", "\e[1;38;5;16;48;5;16mx\e[0m"],
      ["123", "\e[38;5;123mx\e[0m", "\e[48;5;123mx\e[0m", "\e[1;38;5;123;48;5;123mx\e[0m"],
      ["231", "\e[38;5;231mx\e[0m", "\e[48;5;231mx\e[0m", "\e[1;38;5;231;48;5;231mx\e[0m"],
      ["232", "\e[38;5;232mx\e[0m", "\e[48;5;232mx\e[0m", "\e[1;38;5;232;48;5;232mx\e[0m"],
      ["244", "\e[38;5;244mx\e[0m", "\e[48;5;244mx\e[0m", "\e[1;38;5;244;48;5;244mx\e[0m"],
      ["255", "\e[38;5;255mx\e[0m", "\e[48;5;255mx\e[0m", "\e[1;38;5;255;48;5;255mx\e[0m"],
      ["", "x", "x", "\e[1mx\e[0m"],
      ["abc", "x", "x", "\e[1mx\e[0m"],
      ["-1", "\e[29mx\e[0m", "\e[39mx\e[0m"],
      ["+5", "\e[35mx\e[0m", "\e[45mx\e[0m", "\e[1;35;45mx\e[0m"],
      ["007", "\e[37mx\e[0m", "\e[47mx\e[0m", "\e[1;37;47mx\e[0m"],
      [:adapt_hex, "\e[38;2;255;0;0mx\e[0m", "\e[48;2;255;0;0mx\e[0m", "\e[1;38;2;255;0;0;48;2;255;0;0mx\e[0m"],
      [:adapt_ansi, "\e[32mx\e[0m", "\e[42mx\e[0m", "\e[1;32;42mx\e[0m"],
      [:complete, "\e[38;2;18;52;86mx\e[0m", "\e[48;2;18;52;86mx\e[0m", "\e[1;38;2;18;52;86;48;2;18;52;86mx\e[0m"],
      [:complete_adapt, "\e[38;2;51;34;17mx\e[0m", "\e[48;2;51;34;17mx\e[0m", "\e[1;38;2;51;34;17;48;2;51;34;17mx\e[0m"],
      ["300", "\e[38;5;300mx\e[0m", "\e[48;5;300mx\e[0m", "\e[1;38;5;300;48;5;300mx\e[0m"],
      ["#88f0af", "\e[38;2;136;240;175mx\e[0m", "\e[48;2;136;240;175mx\e[0m"],
      ["#32e4c4", "\e[38;2;50;227;195mx\e[0m", "\e[48;2;50;227;195mx\e[0m"],
      ["#a8c219", "\e[38;2;168;194;25mx\e[0m", "\e[48;2;168;194;25mx\e[0m"],
      ["#a829f6", "\e[38;2;168;40;246mx\e[0m", "\e[48;2;168;40;246mx\e[0m"],
      ["#350397", "\e[38;2;52;3;151mx\e[0m", "\e[48;2;52;3;151mx\e[0m"],
      ["#a13667", "\e[38;2;161;54;103mx\e[0m", "\e[48;2;161;54;103mx\e[0m"],
      ["#8d0a17", "\e[38;2;141;10;23mx\e[0m", "\e[48;2;141;10;23mx\e[0m"],
      ["134", "\e[38;5;134mx\e[0m", "\e[48;5;134mx\e[0m"],
      ["87", "\e[38;5;87mx\e[0m", "\e[48;5;87mx\e[0m"]
    ],
    # pty, COLORTERM=truecolor TERM=xterm-256color, light OSC 11 reply
    [:true_color, false] => [
      ["#ff8000", "\e[38;2;255;128;0mx\e[0m", "\e[48;2;255;128;0mx\e[0m", "\e[1;38;2;255;128;0;48;2;255;128;0mx\e[0m"],
      [:adapt_hex, "\e[38;2;0;0;255mx\e[0m", "\e[48;2;0;0;255mx\e[0m", "\e[1;38;2;0;0;255;48;2;0;0;255mx\e[0m"],
      [:adapt_ansi, "\e[31mx\e[0m", "\e[41mx\e[0m", "\e[1;31;41mx\e[0m"],
      [:complete, "\e[38;2;18;52;86mx\e[0m", "\e[48;2;18;52;86mx\e[0m", "\e[1;38;2;18;52;86;48;2;18;52;86mx\e[0m"],
      [:complete_adapt, "\e[38;2;170;187;204mx\e[0m", "\e[48;2;170;187;204mx\e[0m", "\e[1;38;2;170;187;204;48;2;170;187;204mx\e[0m"]
    ],
    # pty, TERM=xterm-256color, light OSC 11 reply
    [:ansi256, false] => [
      ["#ff8000", "\e[38;5;208mx\e[0m", "\e[48;5;208mx\e[0m", "\e[1;38;5;208;48;5;208mx\e[0m"],
      ["#f80", "\e[38;5;208mx\e[0m", "\e[48;5;208mx\e[0m", "\e[1;38;5;208;48;5;208mx\e[0m"],
      ["#zzz", "x", "x", "\e[1mx\e[0m"],
      ["#12345", "\e[38;5;22mx\e[0m", "\e[48;5;22mx\e[0m", "\e[1;38;5;22;48;5;22mx\e[0m"],
      ["#000000", "\e[38;5;16mx\e[0m", "\e[48;5;16mx\e[0m", "\e[1;38;5;16;48;5;16mx\e[0m"],
      ["#ffffff", "\e[38;5;231mx\e[0m", "\e[48;5;231mx\e[0m", "\e[1;38;5;231;48;5;231mx\e[0m"],
      ["#808080", "\e[38;5;102mx\e[0m", "\e[48;5;102mx\e[0m", "\e[1;38;5;102;48;5;102mx\e[0m"],
      ["1", "\e[31mx\e[0m", "\e[41mx\e[0m", "\e[1;31;41mx\e[0m"],
      ["9", "\e[91mx\e[0m", "\e[101mx\e[0m", "\e[1;91;101mx\e[0m"],
      ["123", "\e[38;5;123mx\e[0m", "\e[48;5;123mx\e[0m", "\e[1;38;5;123;48;5;123mx\e[0m"],
      ["", "x", "x", "\e[1mx\e[0m"],
      ["-1", "\e[29mx\e[0m", "\e[39mx\e[0m"],
      [:adapt_hex, "\e[38;5;21mx\e[0m", "\e[48;5;21mx\e[0m", "\e[1;38;5;21;48;5;21mx\e[0m"],
      [:adapt_ansi, "\e[31mx\e[0m", "\e[41mx\e[0m", "\e[1;31;41mx\e[0m"],
      [:complete, "\e[38;5;200mx\e[0m", "\e[48;5;200mx\e[0m", "\e[1;38;5;200;48;5;200mx\e[0m"],
      [:complete_adapt, "\e[38;5;100mx\e[0m", "\e[48;5;100mx\e[0m", "\e[1;38;5;100;48;5;100mx\e[0m"],
      ["300", "\e[38;5;300mx\e[0m", "\e[48;5;300mx\e[0m", "\e[1;38;5;300;48;5;300mx\e[0m"],
      ["#88f0af", "\e[38;5;121mx\e[0m", "\e[48;5;121mx\e[0m"],
      ["#32e4c4", "\e[38;5;80mx\e[0m", "\e[48;5;80mx\e[0m"],
      ["#a8c219", "\e[38;5;142mx\e[0m", "\e[48;5;142mx\e[0m"],
      ["#a829f6", "\e[38;5;129mx\e[0m", "\e[48;5;129mx\e[0m"],
      ["#3b9643", "\e[38;5;65mx\e[0m", "\e[48;5;65mx\e[0m"],
      ["#6cd0d3", "\e[38;5;80mx\e[0m", "\e[48;5;80mx\e[0m"],
      ["#350397", "\e[38;5;54mx\e[0m", "\e[48;5;54mx\e[0m"],
      ["#a13667", "\e[38;5;131mx\e[0m", "\e[48;5;131mx\e[0m"],
      ["#5d855c", "\e[38;5;65mx\e[0m", "\e[48;5;65mx\e[0m"],
      ["#d9ecb9", "\e[38;5;193mx\e[0m", "\e[48;5;193mx\e[0m"],
      ["#dadd8e", "\e[38;5;186mx\e[0m", "\e[48;5;186mx\e[0m"],
      ["#8d0a17", "\e[38;5;88mx\e[0m", "\e[48;5;88mx\e[0m"],
      ["#496e48", "\e[38;5;59mx\e[0m", "\e[48;5;59mx\e[0m"],
      ["#34d159", "\e[38;5;77mx\e[0m", "\e[48;5;77mx\e[0m"],
      ["134", "\e[38;5;134mx\e[0m", "\e[48;5;134mx\e[0m"]
    ],
    # pty, TERM=xterm, dark OSC 11 reply
    [:ansi, true] => [
      ["#ff8000", "\e[91mx\e[0m", "\e[101mx\e[0m", "\e[1;91;101mx\e[0m"],
      ["#zzz", "x", "x", "\e[1mx\e[0m"],
      ["#12345", "\e[32mx\e[0m", "\e[42mx\e[0m", "\e[1;32;42mx\e[0m"],
      ["#000000", "\e[30mx\e[0m", "\e[40mx\e[0m", "\e[1;30;40mx\e[0m"],
      ["#ffffff", "\e[97mx\e[0m", "\e[107mx\e[0m", "\e[1;97;107mx\e[0m"],
      ["#808080", "\e[90mx\e[0m", "\e[100mx\e[0m", "\e[1;90;100mx\e[0m"],
      ["0", "\e[30mx\e[0m", "\e[40mx\e[0m", "\e[1;30;40mx\e[0m"],
      ["7", "\e[37mx\e[0m", "\e[47mx\e[0m", "\e[1;37;47mx\e[0m"],
      ["8", "\e[90mx\e[0m", "\e[100mx\e[0m", "\e[1;90;100mx\e[0m"],
      ["15", "\e[97mx\e[0m", "\e[107mx\e[0m", "\e[1;97;107mx\e[0m"],
      ["16", "\e[30mx\e[0m", "\e[40mx\e[0m", "\e[1;30;40mx\e[0m"],
      ["123", "\e[96mx\e[0m", "\e[106mx\e[0m", "\e[1;96;106mx\e[0m"],
      ["231", "\e[97mx\e[0m", "\e[107mx\e[0m", "\e[1;97;107mx\e[0m"],
      ["232", "\e[30mx\e[0m", "\e[40mx\e[0m", "\e[1;30;40mx\e[0m"],
      ["244", "\e[90mx\e[0m", "\e[100mx\e[0m", "\e[1;90;100mx\e[0m"],
      ["255", "\e[97mx\e[0m", "\e[107mx\e[0m", "\e[1;97;107mx\e[0m"],
      ["", "x", "x", "\e[1mx\e[0m"],
      ["-1", "\e[29mx\e[0m", "\e[39mx\e[0m"],
      ["+5", "\e[35mx\e[0m", "\e[45mx\e[0m", "\e[1;35;45mx\e[0m"],
      [:adapt_hex, "\e[91mx\e[0m", "\e[101mx\e[0m", "\e[1;91;101mx\e[0m"],
      [:adapt_ansi, "\e[32mx\e[0m", "\e[42mx\e[0m", "\e[1;32;42mx\e[0m"],
      [:complete, "\e[31mx\e[0m", "\e[41mx\e[0m", "\e[1;31;41mx\e[0m"],
      [:complete_adapt, "\e[94mx\e[0m", "\e[104mx\e[0m", "\e[1;94;104mx\e[0m"],
      ["#88f0af", "\e[92mx\e[0m", "\e[102mx\e[0m"],
      ["#32e4c4", "\e[96mx\e[0m", "\e[106mx\e[0m"],
      ["#a8c219", "\e[33mx\e[0m", "\e[43mx\e[0m"],
      ["#a829f6", "\e[94mx\e[0m", "\e[104mx\e[0m"],
      ["#3b9643", "\e[32mx\e[0m", "\e[42mx\e[0m"],
      ["#6cd0d3", "\e[96mx\e[0m", "\e[106mx\e[0m"],
      ["#350397", "\e[94mx\e[0m", "\e[104mx\e[0m"],
      ["#a13667", "\e[90mx\e[0m", "\e[100mx\e[0m"],
      ["#5d855c", "\e[32mx\e[0m", "\e[42mx\e[0m"],
      ["#d9ecb9", "\e[92mx\e[0m", "\e[102mx\e[0m"],
      ["#dadd8e", "\e[93mx\e[0m", "\e[103mx\e[0m"],
      ["#8d0a17", "\e[31mx\e[0m", "\e[41mx\e[0m"],
      ["#496e48", "\e[90mx\e[0m", "\e[100mx\e[0m"],
      ["#34d159", "\e[92mx\e[0m", "\e[102mx\e[0m"],
      ["134", "\e[95mx\e[0m", "\e[105mx\e[0m"],
      ["175", "\e[95mx\e[0m", "\e[105mx\e[0m"],
      ["109", "\e[36mx\e[0m", "\e[46mx\e[0m"],
      ["188", "\e[37mx\e[0m", "\e[47mx\e[0m"],
      ["108", "\e[92mx\e[0m", "\e[102mx\e[0m"],
      ["87", "\e[96mx\e[0m", "\e[106mx\e[0m"],
      ["39", "\e[94mx\e[0m", "\e[104mx\e[0m"],
      ["26", "\e[94mx\e[0m", "\e[104mx\e[0m"]
    ],
    # pty, TERM=xterm COLORFGBG="0;15", terminal answers only the cursor position report
    [:ansi, false] => [
      [:adapt_hex, "\e[94mx\e[0m", "\e[104mx\e[0m", "\e[1;94;104mx\e[0m"],
      [:adapt_ansi, "\e[31mx\e[0m", "\e[41mx\e[0m", "\e[1;31;41mx\e[0m"],
      [:complete, "\e[31mx\e[0m", "\e[41mx\e[0m", "\e[1;31;41mx\e[0m"],
      [:complete_adapt, "\e[33mx\e[0m", "\e[43mx\e[0m", "\e[1;33;43mx\e[0m"]
    ],
    # stdout piped, COLORTERM=truecolor
    [:ascii, true] => [
      ["#ff8000", "x", "x", "x"],
      ["#zzz", "x", "x", "x"],
      ["1", "x", "x", "x"],
      ["123", "x", "x", "x"],
      ["", "x", "x", "x"],
      ["-1", "x", "x"],
      [:adapt_hex, "x", "x", "x"],
      [:complete, "x", "x", "x"],
      [:complete_adapt, "x", "x", "x"]
    ]
  }.freeze

  # Stands in for stdout in profile detection.
  FakeIO = Struct.new(:tty) do
    def tty? = tty
  end

  def teardown
    Renderer.default = nil
  end

  # --- ColorBlend ---

  def test_blends_match_the_gem
    RECORDED_BLENDS.each do |a, b, t, luv, rgb, hcl|
      assert_equal luv, Lipgloss::ColorBlend.blend_luv(a, b, t), "blend_luv(#{a}, #{b}, #{t})"
      assert_equal rgb, Lipgloss::ColorBlend.blend_rgb(a, b, t), "blend_rgb(#{a}, #{b}, #{t})"
      assert_equal hcl, Lipgloss::ColorBlend.blend_hcl(a, b, t), "blend_hcl(#{a}, #{b}, #{t})"
      assert_equal luv, Lipgloss::ColorBlend.blend(a, b, t)
      assert_equal rgb, Lipgloss::ColorBlend.blend(a, b, t, mode: :rgb)
      assert_equal hcl, Lipgloss::ColorBlend.blend(a, b, t, mode: Lipgloss::ColorBlend::HCL)
    end
  end

  def test_blend_steps_match_the_gem
    RECORDED_STEPS.each do |a, b, steps, mode, expected|
      assert_equal expected, Lipgloss::ColorBlend.blends(a, b, steps, mode: mode), "blends(#{a}, #{b}, #{steps}, #{mode})"
    end
  end

  def test_grids_match_the_gem
    RECORDED_GRIDS.each do |corners, nx, ny, mode, expected|
      assert_equal expected, Lipgloss::ColorBlend.grid(*corners, nx, ny, mode: mode)
    end
  end

  def test_blend_edge_cases_match_the_gem
    blend = Lipgloss::ColorBlend
    assert_equal %i[luv rgb hcl], [blend::LUV, blend::RGB, blend::HCL]
    assert_equal "#be0090", blend.blend("#f00", "#00f", 0.5, mode: :bogus)
    assert_equal "#be0090", blend.blend("#f00", "#00f", 0.5, mode: nil)
    assert_equal "#be0090", blend.blend("#f00", "#00f", 0.5, foo: 1)
    assert_equal "#800080", blend.blend("#f00", "#00f", 0.5, mode: :rgb)
    assert_equal "#0000ff", blend.blend("#f00", "#00f", 1)
    assert_equal "#d50076", blend.blend("#f00", "#00f", 1r / 3)
    # unparsable colors return the first argument unchanged
    assert_equal "zz", blend.blend("zz", "#00f", 0.5)
    assert_equal "#ff0000", blend.blend("#ff0000", "zz", 0.5)
    assert_equal "", blend.blend("", "", 0.5)
    assert_equal Encoding::UTF_8, blend.blend("", "", 0.5).encoding
    # fmt.Sscanf quirks in colorful.Hex
    assert_equal "#14387f", blend.blend("#12345", "#00f", 0.5)
    assert_equal "#b9b9b9", blend.blend("#ffffffzz", "#000", 0.25)
    assert_equal "#0f0fff", blend.blend("#f f ff", "#000", 0.0)
    assert_equal "# ffff", blend.blend("# ffff", "#000", 0.0)
    assert_equal "#  ffff", blend.blend("#  ffff", "#000", 0.0)
    assert_equal "#f_f", blend.blend("#f_f", "#000", 0.0)
    assert_equal "#777777", blend.blend("#FFF", "#000", 0.5)
    assert_equal "#ff00", blend.blend("#ff00", "#000", 0.0)
    assert_equal "#f\nf", blend.blend("#f\nf", "#000", 0.0)
    assert_equal "#é", blend.blend("#é", "#000", 0.0)
    # out-of-range t: Go's float -> uint8 conversion wraps / saturates
    assert_equal "#5800a7", blend.blend("#f00", "#00f", 2.0)
    assert_equal "#b500a0", blend.blend("#f00", "#00f", -1.5)
    assert_equal "#0300fd", blend.blend("#f00", "#00f", 3.0, mode: :rgb)
    assert_equal "#fc0004", blend.blend("#f00", "#00f", -3.0, mode: :rgb)
    assert_equal "#a2d500", blend.blend("#f00", "#0f0", 5.0)
    assert_equal "#000000", blend.blend("#f00", "#0f0", Float::NAN)
    assert_equal "#00ff00", blend.blend("#f00", "#0f0", Float::INFINITY, mode: :rgb)
    assert_equal "#00ff00", blend.blend("#f00", "#0f0", 1e10, mode: :rgb)
    assert_equal "#ff0000", blend.blend("#f00", "#0f0", -1e10, mode: :rgb)
    assert_equal "#00ffb5", blend.blend("#f00", "#0f0", 1.3, mode: :hcl)
    # steps
    assert_equal [], blend.blends("#f00", "#00f", 0)
    assert_equal ["#ff0000"], blend.blends("#f00", "#00f", 1)
    assert_equal ["#ff0000", "#0000ff"], blend.blends("#f00", "#00f", 2.7)
    assert_equal [], blend.blends("bad", "#00f", 3)
    assert_equal [["#ff0000"]], blend.grid("#f00", "#0f0", "#00f", "#fff", 1, 1, mode: :rgb)
    assert_equal [[], []], blend.grid("#f00", "#0f0", "#00f", "#fff", 0, 2)
    assert_equal [], blend.grid("#f00", "#0f0", "#00f", "#fff", 2, 0)
    assert_equal [], blend.grid("#f00", "#0f0", "#00f", "x", 2, 2)
  end

  def test_blend_argument_errors_match_the_gem
    blend = Lipgloss::ColorBlend
    assert_error(TypeError, "wrong argument type String (expected Symbol)") { blend.blend("#f00", "#00f", 0.5, mode: "rgb") }
    assert_error(TypeError, "no implicit conversion to float from string") { blend.blend("#f00", "#00f", "0.5") }
    assert_error(TypeError, "no implicit conversion to float from nil") { blend.blend("#f00", "#00f", nil) }
    assert_error(TypeError, "wrong argument type Symbol (expected String)") { blend.blend(:a, "#00f", 0.5) }
    assert_error(TypeError, "wrong argument type nil (expected String)") { blend.blend(nil, "#00f", 0.5) }
    assert_error(TypeError, "wrong argument type Integer (expected String)") { blend.blend("#f00", 5, 0.5) }
    assert_error(ArgumentError, "string contains null byte") { blend.blend("#f\0", "#00f", 0.5) }
    assert_error(ArgumentError, "wrong number of arguments (given 4, expected 3)") { blend.blend("#f00", "#00f", 0.5, :rgb) }
    assert_error(ArgumentError, "wrong number of arguments (given 2, expected 3)") { blend.blend("#f00", "#00f") }
    assert_error(ArgumentError, "wrong number of arguments (given 4, expected 3)") { blend.blend_rgb("#f00", "#00f", 0.5, 1) }
    assert_error(TypeError, "no implicit conversion of String into Integer") { blend.blends("#f00", "#00f", "3") }
    assert_error(TypeError, "no implicit conversion from nil to integer") { blend.blends("#f00", "#00f", nil) }
    assert_error(RangeError, "integer 1099511627776 too big to convert to 'int'") { blend.blends("#f00", "#00f", 2**40) }
    assert_error(TypeError, "wrong argument type String (expected Symbol)") { blend.blends("#f00", "#00f", 3, mode: "x") }
    assert_error(TypeError, "wrong argument type Integer (expected String)") { blend.grid("#f00", "#0f0", "#00f", 1, 2, 2) }
  end

  # --- Escape sequences per profile ---

  def test_sgr_sequences_match_the_gem
    RECORDED_SGR.each do |(profile, dark), rows|
      renderer = Renderer.new(Termenv::Output.new(io: FakeIO.new(false), env: {}))
      renderer.color_profile = profile
      renderer.has_dark_background = dark
      rows.each do |value, fg, bg, both|
        color = Renderer.terminal_color(COMPOSITE.fetch(value, value)).color(renderer)
        style = renderer.color_profile.string
        got = [style.foreground(color).styled("x"), style.background(color).styled("x")]
        got << style.bold.foreground(color).background(color).styled("x") if both
        assert_equal [fg, bg, both].compact, got, "#{value.inspect} in #{profile} (dark: #{dark})"
      end
    end
  end

  def test_termenv_style_attributes
    style = Termenv::Profile::ANSI.string
    assert_equal "\e[1;2;3;4;53;5;7;9mx\e[0m", style.bold.faint.italic.underline.overline.blink.reverse.cross_out.styled("x")
    assert_equal "x", style.styled("x")
    assert_equal "x", Termenv::Profile::ASCII.string.bold.styled("x")
    # termenv.Style{} is the TrueColor profile; NoColor still adds an (empty) parameter
    assert_equal "\e[;mx\e[0m", Termenv::Style.new.foreground(Termenv::NoColor.new).background(Termenv::NoColor.new).styled("x")
    assert_equal "x", Termenv::Style.new.foreground(nil).styled("x")
  end

  def test_terminal_color_errors_match_the_gem
    to_str = Struct.new(:to_str)
    complete = Lipgloss::CompleteColor.new(true_color: "#fff", ansi256: 1, ansi: 1)
    assert_error(TypeError, "wrong argument type Integer (expected String)") { Renderer.terminal_color(1) }
    assert_error(TypeError, "wrong argument type nil (expected String)") { Renderer.terminal_color(nil) }
    assert_error(TypeError, "wrong argument type Symbol (expected String)") { Renderer.terminal_color(:red) }
    assert_error(TypeError, "wrong argument type Float (expected String)") { Renderer.terminal_color(1.5) }
    assert_error(TypeError, /wrong argument type .* \(expected String\)/) { Renderer.terminal_color(to_str.new("#fff")) }
    assert_error(ArgumentError, "string contains null byte") { Renderer.terminal_color("#f\0") }
    assert_error(TypeError, "no implicit conversion of Integer into String") do
      Renderer.terminal_color(Lipgloss::AdaptiveColor.new(light: 1, dark: "x"))
    end
    assert_instance_of Gloss::TerminalColor::AdaptiveColor,
                       Renderer.terminal_color(Lipgloss::AdaptiveColor.new(light: to_str.new("#fff"), dark: "x"))
    assert_error(TypeError, "no implicit conversion of nil into String") do
      Renderer.terminal_color(Lipgloss::CompleteColor.new(true_color: nil, ansi256: 1, ansi: 1))
    end
    assert_error(TypeError, "no implicit conversion of Lipgloss::CompleteColor into String") do
      Renderer.terminal_color(Lipgloss::CompleteAdaptiveColor.new(light: complete, dark: "#000"))
    end
    # border colors: adaptive only
    assert_error(TypeError, "wrong argument type Lipgloss::CompleteColor (expected String)") do
      Renderer.terminal_color(complete, complete: false)
    end
    assert_error(TypeError, "no implicit conversion of Lipgloss::CompleteColor into String") do
      Renderer.terminal_color(Lipgloss::CompleteAdaptiveColor.new(light: complete, dark: complete), complete: false)
    end
    # margin background: strings only
    assert_error(TypeError, "wrong argument type Lipgloss::AdaptiveColor (expected String)") do
      Renderer.terminal_color(Lipgloss::AdaptiveColor.new(light: "1", dark: "2"), adaptive: false, complete: false)
    end
  end

  # --- Profile and background detection ---

  def test_color_profile_detection
    cases = [
      # recorded from the gem
      [true, { "COLORTERM" => "truecolor", "TERM" => "xterm-256color" }, :true_color],
      [true, { "TERM" => "xterm-256color" }, :ansi256],
      [true, { "TERM" => "xterm" }, :ansi],
      [true, { "TERM" => "dumb" }, :ascii],
      [true, { "TERM" => "xterm-256color", "COLORTERM" => "truecolor", "NO_COLOR" => "1" }, :ascii],
      [false, { "COLORTERM" => "truecolor", "TERM" => "xterm-256color" }, :ascii],
      [false, { "TERM" => "xterm-256color", "CLICOLOR_FORCE" => "1" }, :ansi],
      # from termenv_unix.go / termenv.go
      [true, { "COLORTERM" => "24bit" }, :true_color],
      [true, { "COLORTERM" => "TrueColor", "TERM" => "screen-256color" }, :ansi256],
      [true, { "COLORTERM" => "truecolor", "TERM" => "screen", "TERM_PROGRAM" => "tmux" }, :true_color],
      [true, { "COLORTERM" => "yes" }, :ansi256],
      [true, { "TERM" => "xterm-kitty" }, :true_color],
      [true, { "TERM" => "linux" }, :ansi],
      [true, { "TERM" => "xterm-color" }, :ansi],
      [true, { "TERM" => "vt100-ansi" }, :ansi],
      [true, { "GOOGLE_CLOUD_SHELL" => "true" }, :true_color],
      [true, { "COLORTERM" => "truecolor", "CI" => "1" }, :ascii],
      [true, { "TERM" => "xterm-256color", "CLICOLOR" => "0" }, :ascii],
      [true, { "TERM" => "xterm-256color", "CLICOLOR" => "0", "CLICOLOR_FORCE" => "1" }, :ansi256],
      [true, { "TERM" => "dumb", "CLICOLOR_FORCE" => "1" }, :ansi],
      [true, { "TERM" => "dumb", "CLICOLOR_FORCE" => "0" }, :ascii]
    ]
    cases.each do |tty, env, expected|
      output = Termenv::Output.new(io: FakeIO.new(tty), env: env)
      assert_equal expected, output.env_color_profile.to_sym, "tty=#{tty} #{env}"
    end
  end

  def test_renderer_detects_once_and_test_hooks_override
    env = { "TERM" => "xterm-256color" }
    Renderer.default = Renderer.new(Termenv::Output.new(io: FakeIO.new(true), env: env))
    assert_equal Termenv::Profile::ANSI256, Renderer.color_profile
    env["COLORTERM"] = "truecolor"
    assert_equal Termenv::Profile::ANSI256, Renderer.color_profile, "detected once"

    Renderer.color_profile = :ascii
    assert_equal Termenv::Profile::ASCII, Renderer.color_profile
    Renderer.color_profile = nil
    assert_equal Termenv::Profile::TRUE_COLOR, Renderer.color_profile, "nil re-detects"

    assert Renderer.has_dark_background?, "not a terminal reads as dark"
    Renderer.has_dark_background = false
    refute Lipgloss.has_dark_background?
    Renderer.reset!
    assert Lipgloss.has_dark_background?
    assert_raises(ArgumentError) { Renderer.color_profile = :sixteen }
  end

  # Background detection can wait seconds on the terminal; it must not hold the renderer's lock.
  class SlowOutput < Termenv::Output
    attr_reader :started, :release

    def initialize
      super(io: FakeIO.new(true), env: { "TERM" => "xterm-256color" })
      @started = Queue.new
      @release = Queue.new
    end

    def has_dark_background?
      @started << true
      @release.pop
    end
  end

  def test_background_detection_does_not_hold_the_renderer_lock
    output = SlowOutput.new
    renderer = Renderer.new(output)
    detecting = Thread.new { renderer.has_dark_background? }
    output.started.pop
    profile = Thread.new { renderer.color_profile }
    assert profile.join(2), "color_profile blocked behind background detection"
    assert_equal Termenv::Profile::ANSI256, profile.value
    renderer.has_dark_background = false
    refute renderer.has_dark_background?, "explicit value answers during detection"
    output.release << false
    refute detecting.join(2).value
    renderer.has_dark_background = nil
    detecting = Thread.new { renderer.has_dark_background? }
    output.started.pop
    output.release << true
    assert detecting.join(2).value
    assert renderer.has_dark_background?, "stored after detection"
  ensure
    output&.release&.close
  end

  def test_dark_background_without_a_terminal
    output = Termenv::Output.new(io: FakeIO.new(false), env: { "COLORFGBG" => "0;15" })
    assert_equal Termenv::NoColor.new, output.background_color
    assert output.has_dark_background?
  end

  # termStatusReport against a pty: the terminal's answer decides, and echo/canonical mode come back.
  def test_osc_background_query_on_a_pty
    assert_query_result(true, "\e]11;rgb:0000/0000/0000\a\e[1;1R")
    assert_query_result(false, "\e]11;rgb:ffff/ffff/ffff\e\\\e[1;1R")
    assert_query_result(false, "\e]11;rgb:eeee/eeee/eeee\a\e[12;40R")
    assert_query_result(false, "\e[1;1R", env: { "TERM" => "xterm", "COLORFGBG" => "0;15" })
    assert_query_result(true, "\e[1;1R", env: { "TERM" => "xterm", "COLORFGBG" => "15;0" })
    assert_query_result(false, nil, env: { "TERM" => "xterm", "COLORFGBG" => "0;15" })
  end

  # The real default renderer in a child process under a pty, as recorded from the gem: one OSC 11
  # query followed by a cursor position request, sent once, and the terminal is left in echo mode.
  def test_end_to_end_query_matches_the_gem
    [["\e]11;rgb:0000/0000/0000\a\e[1;1R", "true"], ["\e]11;rgb:ffff/ffff/ffff\e\\\e[1;1R", "false"]].each do |reply, dark|
      out, queries = run_in_pty(reply, "COLORTERM" => "truecolor", "TERM" => "xterm-256color")
      assert_equal "#{dark} TrueColor true \e[38;2;255;128;0mx\e[0m", out
      assert_equal "\e]11;?\e\\\e[6n", queries
    end
    out, queries = run_in_pty(nil, "TERM" => "dumb")
    assert_equal "true Ascii true x", out
    assert_equal "", queries
  end

  private

  def assert_error(klass, message, &block)
    error = assert_raises(klass, &block)
    message.is_a?(Regexp) ? assert_match(message, error.message) : assert_equal(message, error.message)
  end

  # An Output on a pty slave we don't control as a terminal: skip the foreground-process-group check.
  class PtyOutput < Termenv::Output
    private

    def foreground?(_tty) = true
  end

  def assert_query_result(dark, reply, env: { "TERM" => "xterm" })
    master, slave = PTY.open
    output = PtyOutput.new(io: slave, env: env, osc_timeout: 0.2)
    responder = Thread.new do
      buf = +""
      until buf.include?("\e[6n")
        IO.select([master], nil, nil, 2) or break
        buf << master.readpartial(256)
      end
      master.write(reply) if reply
      buf
    end
    assert slave.echo?
    assert_equal dark, output.has_dark_background?, "reply #{reply.inspect} env #{env}"
    assert_equal "\e]11;?\e\\\e[6n", responder.value
    assert slave.echo?, "echo restored"
  ensure
    responder&.kill
    master&.close
    slave&.close
  end

  CLEAN_ENV = %w[COLORTERM TERM NO_COLOR CLICOLOR CLICOLOR_FORCE CI COLORFGBG TERM_PROGRAM GOOGLE_CLOUD_SHELL]
              .to_h { |k| [k, nil] }.freeze

  # Runs the default renderer in a child whose controlling terminal is a pty, answering its query with
  # `reply`. Returns the child's report and every byte it wrote to the terminal.
  def run_in_pty(reply, env)
    code = <<~RUBY
      require "r2ui/compat/lipgloss"
      r = R2UI::Compat::Gloss::Renderer
      dark = Lipgloss.has_dark_background?
      dark = Lipgloss.has_dark_background?
      fg = r.color_profile.string.foreground(r.color("#ff8000")).styled("x")
      File.write(ENV.fetch("R2UI_TEST_OUT"), [dark, r.color_profile.name, STDOUT.echo?, fg].join(" "))
    RUBY
    out_path = File.join(Dir.tmpdir, "r2ui-color-test-#{Process.pid}-#{rand(1 << 30)}")
    master, writer, pid = PTY.spawn(CLEAN_ENV.merge(env).merge("R2UI_TEST_OUT" => out_path),
                                    RbConfig.ruby, "-I", LIB, "-rio/console", "-e", code)
    queries = +""
    replied = false
    deadline = Time.now + 10
    until Process.wait(pid, Process::WNOHANG)
      flunk "child did not finish" if Time.now > deadline
      next unless IO.select([master], nil, nil, 0.05)

      chunk = begin
        master.read_nonblock(256)
      rescue IO::WaitReadable, EOFError, Errno::EIO
        ""
      end
      queries << chunk
      next unless reply && !replied && queries.end_with?("\e[6n")

      writer.write(reply)
      replied = true
    end
    pid = nil
    [File.read(out_path), queries]
  ensure
    if pid
      begin
        Process.kill("KILL", pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
    [master, writer].each { |io| io.close if io && !io.closed? }
    File.delete(out_path) if out_path && File.exist?(out_path)
  end
end
