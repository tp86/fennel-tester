#!/usr/bin/env -S fennel --correlate

(local luarocks-tree ".luarocks")
(local file-patterns
  {:path ["?.lua" "?/init.lua"]
   :cpath ["?.so"]
   :macro-path ["src/?-macros.fnl"]
   :fnl-path ["src/?.fnl"]})

(local lua-version (_VERSION:match "Lua (.*)"))
(local separator (package.config:sub 1 1))

(local current-directory (-> (debug.getinfo 1 :S)
                             (. :source)
                             (: :match "@(.*)")
                             (: :match (.. "(.*)" separator))))

(fn make-paths [key path-sequence]
  (icollect [_ pattern (ipairs (. file-patterns key))]
    (do
      (table.insert path-sequence pattern)
      (table.concat path-sequence separator))))

(macro prepend-path [pattern path]
  `(set ,path (.. ,pattern ";" ,path)))

;; TODO refactor
(each [_ path (ipairs (make-paths :path [luarocks-tree "share" "lua" lua-version]))]
  (prepend-path path package.path))
(each [_ path (ipairs (make-paths :cpath [luarocks-tree "lib" "lua" lua-version]))]
  (prepend-path path package.cpath))
(let [fennel (require :fennel)]
  (prepend-path (.. current-directory separator "?-macros.fnl") fennel.macro-path)
  (each [_ path (ipairs (make-paths :macro-path []))]
     (prepend-path path fennel.macro-path))
  (prepend-path (.. current-directory separator "?.fnl") fennel.path)
  (each [_ path (ipairs (make-paths :fnl-path []))]
     (prepend-path path fennel.path)))

(fn dir? [path]
  (local lfs (require :lfs))
  (let [attrs (lfs.attributes path)]
    (when (= attrs nil)
      (error (.. "File not found: " path) 0))
    (= attrs.mode :directory)))

(local fnl-file-pattern "(.*)%.fnl$")

(fn find-fnl-files [path ?found]
  (local lfs (require :lfs))
  (local found (or ?found []))
  (if (dir? path)
      (each [item (lfs.dir path)]
        (when (and (~= item "..") (~= item "."))
          (let [item-path (.. path "/" item)]
            (find-fnl-files item-path found))))

      (path:match fnl-file-pattern) (table.insert found path))
  found)

(fn basename [path]
  (path:match fnl-file-pattern))

(fn path->module [path]
  (pick-values 1 (-> path
                     (basename)
                     (: :gsub separator "."))))

(fn discover-tests [paths]
  (var test-modules [])
  (each [_ path (ipairs paths)]
    (each [_ file (ipairs (find-fnl-files path))]
      (table.insert test-modules (path->module file))))
  test-modules)

(fn run-tests [test-modules]
  (require :luacov)
  (each [_ module-name (ipairs test-modules)]
    (require module-name))
  (let [lu (require :luaunit)]
    (os.exit (lu.LuaUnit.run :-q))))

(fn clear-luacov-out-files []
  (each [_ file (ipairs ["luacov.stats.out" "luacov.report.out"])]
    (os.remove file)))

(fn generate-luacov-report [includes]
  (local runner (require :luacov.runner))
  (local configuration (runner.load_config))
  (when (= nil configuration.include)
    (set configuration.include {}))
  (when (= nil configuration.exclude)
    (set configuration.exclude {}))
  (table.insert configuration.exclude "src%/fennel%/macros.fnl")
  (each [_ pattern (ipairs includes)]
    (table.insert configuration.include pattern))
  (runner.run_report configuration))

(fn print-file [filename]
  (with-open [file (io.open filename)]
    (each [line (file:lines)]
      (print line))))

(fn install-deps []
  (local deps {:luaunit "luaunit"
               :luacov "luacov"
               :lfs "luafilesystem"})
  (each [mod dep (pairs deps)]
    (let [ok (pcall #(require mod))]
      (when (not ok)
        (os.execute (table.concat
                      ["luarocks" "--lua-version" lua-version "--tree" luarocks-tree :install dep]
                      " "))))))

(fn make-dirs []
  (local lfs (require :lfs))
  (each [_ dir (ipairs ["src" "test" "test/suite"])]
    (lfs.mkdir dir)))

(fn make-files []
  (let [files {"test/basic.fnl" "(import-macros {: test} :tester)
(local lu (require :luaunit))

(local basic (require :basic))

(test
  basic
  (lu.assertTrue basic))"
               "test/suite/basic.fnl" "(import-macros {: test : suite : before-each : after-each} :tester)
(local lu (require :luaunit))

(local basic (require :basic))

(suite
  basic
  (var obj nil)
  (before-each
    (set obj true))
  (after-each
    (set obj nil))
  (test
    basic
    (lu.assertTrue basic)
    (lu.assertTrue obj)))"
               ".luacov" "include = {
  \"src%/.+$\",
}
exclude = {
 \"src%/fennel%/macros.fnl\",
}"
               "src/basic.fnl" "true"}]
    (each [filename contents (pairs files)]
      (with-open [file (io.open filename :w)]
        (file:write contents)))))

(local commands
  {:test (fn [paths]
           (clear-luacov-out-files)
           (let [paths (if (< (length paths) 1) ["test"] paths)
                 test-modules (discover-tests paths)]
             (run-tests test-modules)))
   :setup (fn []
            (install-deps)
            (make-dirs)
            (make-files))
   :cov (fn [includes]
          (generate-luacov-report includes)
          (print-file "luacov.report.out"))})

(fn run [args]
  (let [[command & args] (or args arg)
        command-name (or command :test)
        command (. commands command-name)]
    (if command
      (command args)
      (print (.. "Unknown command: " command-name)))))

(var _suite _G)

(local api
  {: _suite
   : run})

(fn required? []
  (let [caller (-> (debug.getinfo 3 :f)
                   (. :func))]
    (= caller require)))
(if (required?)
  api
  (run))
