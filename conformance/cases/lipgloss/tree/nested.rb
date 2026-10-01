# A subtree added as a child.
require "lipgloss"

src = Lipgloss::Tree.root("src").child("main.rb").child("helper.rb")
Lipgloss::Tree.root("Project").child(src).child("README").render
