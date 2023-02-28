(fn test [id ...]
  `(let [current-file-basename# (-> (debug.getinfo 1 :S)
                                    (. :source)
                                    (: :sub 2)
                                    (: :match "^[./\\]*(.*)%.[^.]*$"))
         tester# (require :tester)
         test-fn# (fn [] ,... nil)
         test-name# (.. "test:" current-file-basename# "::" ,(tostring id))]
     (when (. tester#._suite test-name#)
       (error (.. test-name# " already defined!")))
     (tset tester#._suite test-name# test-fn#)))

(fn suite [id ...]
  `(let [current-file-basename# (-> (debug.getinfo 1 :S)
                                    (. :source)
                                    (: :sub 2)
                                    (: :match "^[./\\]*(.*)%.[^.]*$"))
         tester# (require :tester)
         tester-suite# tester#._suite
         suite# {}
         suite-name# (.. "test-suite:" current-file-basename# "::" ,(tostring id))]
     (when (. tester#._suite suite-name#)
       (error (.. "Suite " suite-name# " already defined!")))
     (tset tester#._suite suite-name# suite#)
     (set tester#._suite suite#)
     [,...]
     (set tester#._suite tester-suite#)
     nil))

(fn before-each [...]
  `(let [tester# (require :tester)]
     (tset tester#._suite :setup (fn [] ,... nil))))

(fn after-each [...]
  `(let [tester# (require :tester)]
     (tset tester#._suite :teardown (fn [] ,... nil))))

{: test
 : suite
 : before-each
 : after-each}
