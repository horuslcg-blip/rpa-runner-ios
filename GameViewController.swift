import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        
        if let skView = view as? SKView {
            skView.presentScene(scene)
            skView.ignoresSiblingOrder = true
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
