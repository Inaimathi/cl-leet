(require 'leet-primitives)
(require 'leet-data)

;; Commands ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; These are all side-effect functions, but don't have the bang because they may require the user to type them out
(defun cap-info ()
  (interactive)
  (insert (captain-info current-captain)))

(defun plt-info ()
  (interactive)
  (insert (planet-info (planet-name->planet (captain-current-planet current-captain)))))

(defun market ()
  (interactive)
  (mapcar 'insert 
	  (market-info (planet-market (planet-name->planet (captain-current-planet current-captain))))))

(defun cargo ()
  (interactive)
  (insert (inventory (captain-ship current-captain))))

(defun local-planets ()
  (interactive)
  (mapcar (lambda (p) (insert p "\n"))
	  (list-local-planets current-captain)))

(defun travel (p)
  (interactive (list (completing-read "Planet Name: " (list-local-planets current-captain))))
  (move-to-planet! current-captain (planet-name->planet p)))

(defun buy (t-name num)
  (interactive "sTradegood: \nnAmount: ")
  (purchase! current-captain t-name num))

(defun sell (t-name num)
  (interactive "sTradegood: \nnAmount: ")
  (convey! current-captain t-name num))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Actions ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun move-to-planet! (a-cap p)
  "Takes a captain and a planet, and moves the captain to the planet if its within rangex"
  (let* ((fuel (ship-fuel (captain-ship a-cap)))
	 (current-planet (planet-name->planet (captain-current-planet a-cap)))
	 (distance (planet-distance current-planet p))
	 (fuel-range (/ fuel (ship-fuel-consumption (captain-ship a-cap)))))
    (if (>= fuel-range distance)
	(setf (captain-current-planet a-cap) (planet-name p)
	      (ship-fuel (captain-ship a-cap)) (round (- fuel (* distance (ship-fuel-consumption (captain-ship a-cap))))))
      (error "Planet out of range"))))

(defun purchase! (a-cap t-name num)
  "Check if a purchase order is valid, and if so, fulfill it"
  (let ((a-listing (tradegood-available? t-name (planet-market (planet-name->planet (captain-current-planet a-cap))))))
    (cond ((not a-listing) (error "That's not available at this planet"))
	  ((< (listing-amount a-listing) num) (error (format "They don't have that many %s" t-name)))
	  ((< (captain-credits a-cap) (* num (listing-price a-listing))) (error (format "You can't afford that many %s" t-name)))
	  ((not (enough-space? a-cap t-name num)) (error "You don't have enough room in your cargo hold"))
	  (t (setf (listing-amount a-listing) (- (listing-amount a-listing) num) ;; Remoe [num] [t-name] from the planet
		   (captain-credits a-cap) (- (captain-credits a-cap) (* num (listing-price a-listing)))) ;; Remove (* [num] [price]) credits from captains' account
	     (add-to-cargo! a-cap t-name num)
	     (record-trade-history! a-cap 'buy (captain-current-planet a-cap) num (capitalize t-name) (listing-price a-listing))
	     (format "Bought %s %s" num t-name)))))

(defun convey! (a-cap t-name num)
  "Check if a sell order is valid, and if so, fulfill it"
  (let ((sell-price (going-rate (captain-current-planet a-cap) t-name))
	(a-listing (tradegood-available? t-name (ship-cargo (captain-ship a-cap)))))
    (cond ((not sell-price) (error (format "I have no clue what a %s is" t-name)))
	  ((not a-listing) (error (format "You don't have any %s in your hold" t-name)))
	  ((> num (listing-amount a-listing)) (error (format "You don't have enough %s in your hold" t-name)))
	  (t (remove-from-cargo! a-cap t-name num)
	     (add-to-market! (captain-current-planet a-cap) t-name num)
	     (setf (captain-credits a-cap) (+ (captain-credits a-cap) (* sell-price num)))
	     (record-trade-history! a-cap 'sell (captain-current-planet a-cap) num (capitalize t-name) (listing-price a-listing))))))

(defun add-to-market! (p-name t-name num)
  "Add [num] [t-good] to [p-name]s market"
  (let* ((market (planet-market (planet-name->planet p-name)))
	 (a-listing (tradegood-available? t-name market)))
    (if a-listing
	(setf (listing-amount a-listing) (+ (listing-amount a-listing) num))
      (setf market (cons (make-listing :name (capitalize t-name) :amount num :price (going-rate p-name t-name)) market)))))

(defun add-to-cargo! (a-cap t-name num)
  "Add [num] [t-good] to [a-cap]s inventory"
  (let ((a-listing (tradegood-available? t-name (ship-cargo (captain-ship a-cap))))
	(ship (captain-ship a-cap))
	(good (tradegood-name->tradegood t-name)))
    (cond ((and (fuel? good) (> (ship-fuel-space ship) 0)); Fill out fuel-cells before filling out cargo hold if there's space
	   (let ((f-space (ship-fuel-space ship)))
	     (if (>= f-space num)
		 (setf (ship-fuel ship) (+ (ship-fuel ship) num))
	       (progn (setf (ship-fuel ship) (ship-fuel-cap ship))
		      (add-to-cargo! a-cap t-name (- num f-space))))))
	  (a-listing (setf (listing-amount a-listing) (+ (listing-amount a-listing) num)))
	  (t (setf (ship-cargo (captain-ship a-cap))
		   (cons (make-listing :name (capitalize t-name) :amount num) (ship-cargo (captain-ship a-cap)))))))) ;; otherwise add a new entry

(defun remove-from-cargo! (a-cap t-name num)
  "Remove [num] [t-good] from [a-cap]s inventory"
  (let* ((cargo (ship-cargo (captain-ship a-cap)))
	 (a-listing (tradegood-available? t-name cargo)))
    (if (= (listing-amount a-listing) num)
	(setf (ship-cargo (captain-ship a-cap))
	      (remove-if (lambda (l) (string= (capitalize t-name) (listing-name l))) cargo))
      (setf (listing-amount a-listing) (- (listing-amount a-listing) num)))))

(defun record-trade-history! (a-cap type planet amount t-name price/unit)
  (let ((trade (make-trade-record 
		:type type :planet planet
		:amount amount :good t-name :price/unit price/unit)))
    (setf (captain-trade-history a-cap) (cons trade (captain-trade-history a-cap)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Oddly Specific Predicates;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun enough-space? (a-cap t-name num)
  "Takes a [captain], [tradegood-name] and [amount]. Returns true if there is enough room for [amount] [tradegood-name] in [captain]s' ship."
  (let ((g (tradegood-name->tradegood t-name))
	(c-space (ship-cargo-space (captain-ship a-cap)))
	(f-space (ship-fuel-space (captain-ship a-cap))))
    (if (fuel? g)
	(or (>= c-space num) (>= f-space num) (>= (+ c-space f-space) num))
      (>= c-space num))))

(defun fuel? (g)
  "Returns true if [t] is a tradegood of type 'fuel"
  (and (tradegood-p g)
       (eq (tradegood-type g) 'fuel)))

(defun tradegood-available? (t-name inv)
  "Takes a tradegood name and an inventory, returns that tradegoods stats in that inventory (nil if it is unavailable)"
  (let ((n (capitalize t-name)))
    (find-if (lambda (l) (string= n (listing-name l))) inv)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Additional Getters ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun going-rate (p-name t-name)
  "Given a planet name and tradegood name, returns the price/unit of tradegood on planet"
  (let* ((plt (planet-name->planet p-name))
	 (good (tradegood-name->tradegood t-name))
	 (a-listing (tradegood-available? t-name (planet-market plt))))
    (cond ((listing-p a-listing) (listing-price a-listing)) ;; The good is on the market here; use the latest generated price for it
	  ((and (not a-listing) good) (generate-price (planet-radius plt) (planet-tech-level plt) (tradegood-tech-level good) (tradegood-base-price good) (roll-dice 2 4) (roll-dice 2 4))) 
	  (t nil)))) ;; If we've gotten here, it means that the tradegood given doesn't exist in game  

(defun planet-info (p)
  (format "--==[ %s ]==--\n%s\nSize: % 10s\nPopulation: %s\nGovernment: %s\nTech-level: %s\n\n"
	  (planet-name p) (planet-description p) (planet-radius p) (planet-population p) 
	  (planet-government p) (planet-tech-level p)))

(defun captain-info (a-cap)
  (format "--==[ %s ]==--\nCredits: %s\nReputation: %s\nXP: %s\nCurrent Planet: %s\nShip: %s\n\n"
	  (captain-name a-cap) (captain-credits a-cap) (captain-reputation a-cap) (captain-xp a-cap) (captain-current-planet a-cap) (ship-name (captain-ship a-cap))))
  
(defun inventory (s)
  "Takes a ship and outputs the contents of its cargo bay"
  (let ((cargo (ship-cargo s))
	(fuel (ship-fuel s)))
    (format "%s\n%s\n\n" 
	    (if cargo
		(mapcar (lambda (i) (format "%s" i)) cargo)
	      (format "%s has nothing in her hold at the moment." (ship-name s)))
	    (if (> fuel 0)
		(format "Fuel Cells: %s/%s" fuel (ship-fuel-cap s))
	      (format "%s has nothing left in her fuel cells. Bust out the distress beacon, or abandon ship."  
		      (ship-name s))))))

(defun market-info (m)
  "Takes a market and returns the formatted output of all goods available on it"
  (mapcar (lambda (a-listing)
	    (format "--[ %s ]--\nIn Stock: %s\nPrice/unit: %s\n\n" 
		    (listing-name a-listing) (listing-amount a-listing) (listing-price a-listing)))
	  m))

(defun list-local-planets (a-cap)
  "Takes a captain and outputs all directly reachable planets given their ships fuel and fuel-consumption"
  (mapcar (lambda (p) (planet-name p))
	  (systems-in-range (/ (ship-fuel (captain-ship current-captain)) 
			       (ship-fuel-consumption (captain-ship current-captain)))
			    (planet-name->planet (captain-current-planet current-captain)))))

(defun systems-in-range (a-range p)
  "Returns a list of planets within [a-range] of planet [p]"
  (filter (lambda (other-planet)
	    (> a-range (planet-distance p other-planet)))
	  galaxy))

(defun planet-distance (p1 p2)
  "Given two planets, returns the distance between them"
  (flet ((diff-sq (n1 n2) (* (- n1 n2) (- n1 n2))))
    (sqrt (+ (diff-sq (planet-z p1) (planet-z p2))
	     (diff-sq (planet-y p1) (planet-y p2))
	     (diff-sq (planet-x p1) (planet-x p2))))))

(defun planet-name->planet (p-name)
  "Given a planet name, returns that planets' struct (or nil if the planet doesn't exist in the game)"
  (find-if (lambda (p) (string= (planet-name p) p-name)) galaxy))

(defun tradegood-name->tradegood (t-name)
  "Given a tradegood name, returns that tradegoods' struct (or nil if it doesn't exist in the game)"
  (find-if (lambda (g) (string= (tradegood-name g) (capitalize t-name))) tradegoods))

(defun ship-cargo-space (s)
  "Returns amount of free cargo space in the given ship"
  (- (ship-cargo-cap s)
     (apply '+ (mapcar (lambda (a-listing) (or (listing-amount a-listing) 0)) (ship-cargo s)))))

(defun ship-fuel-space (s)
  "Returns amount of free fuel space in the given ship"
  (- (ship-fuel-cap s) (ship-fuel s)))

(provide 'leet)