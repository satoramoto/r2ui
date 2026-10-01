# Every unset_<attribute> clears its attribute, leaving unstyled text.
require "lipgloss"

Lipgloss::Style.new.bold(true).italic(true).faint(true).blink(true).underline(true).strikethrough(true).reverse(true)
  .unset_bold.unset_italic.unset_faint.unset_blink.unset_underline.unset_strikethrough.unset_reverse.render("plain")
