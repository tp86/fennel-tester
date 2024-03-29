(local {: with-splicing} (require :splicing))

(fn current-file-basename []
  `(-> (debug.getinfo 1 :S)
       (. :source)
       (: :sub 2)
       (: :match "^[./\\]*(.*)%.[^.]*$")))

(fn nil-returning-fn [...]
  (with-splicing `(fn [] (&splice ,...) nil)))

(fn test [name ...]
  `(let [current-file-basename# ,(current-file-basename)
         tester# (require :tester)
         test-fn# ,(nil-returning-fn ...) ; test function needs to return nil for correct stacktrace reported by luaunit
         test-name# (.. "test:" current-file-basename# "::" ,name)]
     (when (. tester#._suite test-name#)
       (error (.. test-name# " already defined!")))
     (tset tester#._suite test-name# test-fn#)))

(fn suite [name ...]
  (with-splicing
    `(let [current-file-basename# ,(current-file-basename)
           tester# (require :tester)
           tester-suite# tester#._suite
           suite# {}
           suite-name# (.. "test-suite:" current-file-basename# "::" ,name)]
       (when (. tester#._suite suite-name#)
         (error (.. "Suite " suite-name# " already defined!")))
       (tset tester#._suite suite-name# suite#)
       (set tester#._suite suite#)
       (&splice ,...)
       (set tester#._suite tester-suite#)
       nil)))

(fn make-suite-fn [name ...]
  `(let [tester# (require :tester)]
     (tset tester#._suite ,name ,(nil-returning-fn ...))))

(fn before-each [...]
  (make-suite-fn :setup ...))

(fn after-each [...]
  (make-suite-fn :teardown ...))

{: test
 : suite
 : before-each
 : after-each}
