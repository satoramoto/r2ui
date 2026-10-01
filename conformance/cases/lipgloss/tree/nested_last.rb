# A subtree as the last child uses the closing connector.
require "lipgloss"

src = Lipgloss::Tree.root("src").child("main.rb").child("helper.rb")
Lipgloss::Tree.root("Project").child("README").child(src).render
