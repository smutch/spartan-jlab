(declare-project
  :name "jlab" # required
  :description "Launch JupyterLab instances on Spartan interactive nodes"

  # Optional urls to git repositories that contain required artifacts.
  :dependencies ["cmd" "sh" "spork"])

(declare-executable
  :name "jlab"
  :entry "jlab.janet"
  :install false)
