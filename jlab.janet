#!/usr/bin/env janet

(use sh)
(import cmd)

# {{{ terminal formatting

(defn format [v]
  (def t {:green "\e[0;32m"
          :red "\e[0;31m"
          :yellow "\e[0;33m"
          :bold "\e[1m"
          :grey "\e[0;37m"
          :reset "\e[0m"})
  (get t v))

# }}}

# {{{ jupyter-lab/marimo executable search

(defmacro check-paths [marimo & paths]
  ~(let [exec (if ,marimo "/bin/marimo" "/bin/jupyter-lab")]
     (cond
       ,;(mapcat (fn [path]
                   [~(os/stat (string ,path exec))
                    ~(string ,path exec)])
                 paths))))

(defn traverse-and-check [marimo path]
  (or (check-paths marimo
                   (string path "/.venv")
                   (string path "/.env")
                   (string path "/venv")
                   (string path "/env")
                   (string path "/.pixi/envs/dev")
                   (string path "/.pixi/envs/develop")
                   (string path "/.pixi/envs/default"))
      (when-let [_ (not (os/stat (string path ".git")))
                 parent (string path "/..")
                 _ (os/stat parent)]
        (traverse-and-check marimo parent))))


(defn find-exec [marimo path]
  (or (check-paths marimo
                   (os/getenv "VIRTUAL_ENV")
                   (os/getenv "PIXI_ENV")
                   (os/getenv "CONDA_PREFIX")))
  (traverse-and-check marimo path))

# }}}

(cmd/main
  (cmd/fn
    `
   Launch an interactive JupyterLab/Marimo session.
   `
    [[exec-path --exec -e] (optional :string)
     [--port -P] (optional :number)
     [--time -t] (optional :string "02:00:00")
     [--mem -m] (optional :string "64G")
     [--cpus -c] (optional :string "2")
     [--gpus -G] (optional :number)
     [--partition -p] (optional :string "interactive")
     [--job-name -J] (optional :string "notebook")
     [--marimo] (flag)
     [--dry-run] (flag)
     [--args -a] (optional :string "")]

    (var used-part partition)
    (def path (or exec-path (find-exec marimo (os/getenv "PWD"))))

    (if (nil? path)
      (do
        (printf "%sFailed to find jupyter-lab/marimo executable!%s\n" (format :red) (format :reset))
        (os/exit 1)))

    (printf "\nUsing jupyter-lab/marimo executable at %s\n" path)

    (if (and (= used-part "interactive") gpus)
      (do
        (printf "%sWARNING: Requested gpus and partition=interactive. Setting partion=gpu-a100-short instead.%s\n" (format :yellow) (format :reset))
        (set used-part "gpu-a100-short")))

    (def srun-opts @[])
    (array/push srun-opts (string/format "--time=%s" time))
    (array/push srun-opts (string/format "--mem=%s" mem))
    (array/push srun-opts (string/format "--cpus-per-task=%s" cpus))
    (if gpus (array/push srun-opts (string/format "--gpus=%d" gpus)))
    (array/push srun-opts (string/format "--partition=%s" used-part))
    (array/push srun-opts (string/format "--job-name=%s" job-name))

    (printf "%sUsing srun options: %s%s\n\n" (format :grey) (string/join srun-opts " ") (format :reset))

    (def use-port (or port (let [rand (scan-number ($< bash -c "echo -n $RANDOM"))]
                             (+ (mod rand (+ (- 4999 4001) 1)) 4001))))

    (def connect-string (string/format "ssh -NL %d:localhost:%d -J spartan.hpc.unimelb.edu.au $(hostname -s)" use-port use-port))

    (def exec-opts (if marimo ["edit"] ["--no-browser"]))

    (def submit-script
      (string/format `
           banner() {
                     msg=" $2 "
                     edge=$(echo "$msg" | sed 's/./─/g')
                     echo "%s%s$1"
                     echo "┌$edge┐"
                     echo "│$msg│"
                     echo "└$edge┘%s";}
    
           echo ""
           printf '\033]52;;%%s\033\\' "$(echo -n "%s" | base64)"
           banner "Use this to connect:" "%s"
		   echo "%sIf your terminal (and multiplexer) supports it this command will already be on your clipboard!%s"
		   echo ""
           %s %s --port %d %s
           `
                     (format :yellow) (format :bold) (format :reset) connect-string connect-string (format :grey) (format :reset) path (string/join exec-opts " ") use-port args))

    (if-not dry-run ($ srun ,;srun-opts bash -c ,submit-script))))

# vim: set fdm=marker:

