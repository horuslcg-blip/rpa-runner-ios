import SpriteKit
import AVFoundation

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    private enum GameState {
        case menu, playing, gameOver, completed
    }
    
    private var gameState: GameState = .menu
    
    private var player: SKSpriteNode!
    private var ground: SKShapeNode!
    private var scoreLabel: SKLabelNode!
    private var retryLabel: SKLabelNode!
    
    private var musicPlayer: AVAudioPlayer?
    private var effectPlayers: [AVAudioPlayer] = []
    private var backgroundNodes: [SKSpriteNode] = []
    
    private var executionTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var retry = 1
    private var lastObstacleSpawnTime: TimeInterval = 0
    
    private var logSlowModeActive = false
    
    private let minObstacleInterval: TimeInterval = 1.35
    private let logSlowDuration: TimeInterval = 25
    
    private let playerCategory: UInt32 = 1
    private let obstacleCategory: UInt32 = 2
    private let groundCategory: UInt32 = 4
    private let coinCategory: UInt32 = 8
    
    private let groundY: CGFloat = 40
    private let playerY: CGFloat = 120
    private let obstacleY: CGFloat = 75
    private let coinY: CGFloat = 180
    
    private let completedTime: TimeInterval = 60
    
    private let obstacleTypes = [
        "obstacle_login",
        "obstacle_element",
        "obstacle_system"
    ]
    
    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -12)
        physicsWorld.contactDelegate = self
        
        showMenu()
    }
    
    private func showMenu() {
        removeAllChildren()
        removeAllActions()
        backgroundNodes.removeAll()
        logSlowModeActive = false
        
        gameState = .menu
        playMusic(named: "menu_music", loop: true)
        
        let bg = SKSpriteNode(imageNamed: "screen_menu")
        bg.size = size
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = 1
        addChild(bg)
        
        let play = SKSpriteNode(imageNamed: "button_play")
        play.size = CGSize(width: 180, height: 80)
        play.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
        play.zPosition = 200
        play.name = "play"
        addChild(play)
    }
    
    private func startGame() {
        removeAllChildren()
        removeAllActions()
        backgroundNodes.removeAll()
        
        gameState = .playing
        executionTime = 0
        lastUpdateTime = 0
        retry = 1
        lastObstacleSpawnTime = 0
        logSlowModeActive = false
        
        playMusic(named: "game_music", loop: true)
        
        setupBackground()
        setupGround()
        setupPlayer()
        setupScore()
        setupRetry()
        
        startPlayerAnimation()
        startCoins()
    }
    
    private func setupBackground() {
        let texture = SKTexture(imageNamed: "background")
        texture.filteringMode = .linear
        
        for index in 0...2 {
            let background = SKSpriteNode(texture: texture)
            background.size = size
            background.position = CGPoint(x: size.width / 2 + CGFloat(index) * size.width, y: size.height / 2)
            background.zPosition = -10
            background.name = "background"
            addChild(background)
            backgroundNodes.append(background)
        }
    }
    
    private func moveBackground() {
        let speed: CGFloat = 3
        
        for background in backgroundNodes {
            background.position.x -= speed
            
            if background.position.x <= -size.width / 2 {
                background.position.x += size.width * 3
            }
        }
    }
    
    private func setupGround() {
        ground = SKShapeNode(rectOf: CGSize(width: size.width, height: 30))
        ground.fillColor = .clear
        ground.strokeColor = .clear
        ground.lineWidth = 0
        ground.position = CGPoint(x: size.width / 2, y: groundY)
        ground.zPosition = -1
        
        ground.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width, height: 30))
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = groundCategory
        
        addChild(ground)
    }
    
    private func setupPlayer() {
        player = SKSpriteNode(imageNamed: "player1")
        player.size = CGSize(width: 95, height: 95)
        player.position = CGPoint(x: size.width * 0.18, y: playerY)
        player.zPosition = 10
        
        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 55, height: 70))
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.linearDamping = 0.5
        player.physicsBody?.categoryBitMask = playerCategory
        player.physicsBody?.contactTestBitMask = obstacleCategory | coinCategory
        player.physicsBody?.collisionBitMask = groundCategory
        
        addChild(player)
    }
    
    private func setupScore() {
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 22
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 60)
        scoreLabel.zPosition = 50
        scoreLabel.text = "Tempo: 00:00"
        addChild(scoreLabel)
    }
    
    private func setupRetry() {
        retryLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        retryLabel.fontSize = 20
        retryLabel.fontColor = .white
        retryLabel.position = CGPoint(x: size.width - 80, y: size.height - 60)
        retryLabel.zPosition = 50
        retryLabel.text = "Retry: 1"
        addChild(retryLabel)
    }
    
    private func startPlayerAnimation() {
        let animation = SKAction.animate(with: [
            SKTexture(imageNamed: "player1"),
            SKTexture(imageNamed: "player2")
        ], timePerFrame: 0.2)
        
        player.run(SKAction.repeatForever(animation), withKey: "running")
    }
    
    private func jump() {
        guard gameState == .playing else { return }
        
        if player.position.y <= playerY + 10 {
            player.physicsBody?.velocity = .zero
            player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 120))
            playEffect(named: "jump")
        }
    }
    
    private func trySpawnObstacle(currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        if currentTime - lastObstacleSpawnTime < minObstacleInterval {
            return
        }
        
        spawnObstacle()
        lastObstacleSpawnTime = currentTime
    }
    
    private func currentObstacleDuration() -> TimeInterval {
        return logSlowModeActive ? 2.6 : 1.8
    }
    
    private func spawnObstacle() {
        guard let obstacleName = obstacleTypes.randomElement() else { return }
        
        let obstacle = SKSpriteNode(imageNamed: obstacleName)
        obstacle.size = CGSize(width: 90, height: 90)
        obstacle.position = CGPoint(x: size.width + 50, y: obstacleY)
        obstacle.zPosition = 9
        obstacle.name = "obstacle"
        
        obstacle.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 60, height: 60))
        obstacle.physicsBody?.isDynamic = false
        obstacle.physicsBody?.categoryBitMask = obstacleCategory
        obstacle.physicsBody?.contactTestBitMask = playerCategory
        obstacle.physicsBody?.collisionBitMask = 0
        
        addChild(obstacle)
        
        let move = SKAction.moveTo(x: -50, duration: currentObstacleDuration())
        obstacle.run(SKAction.sequence([move, .removeFromParent()]), withKey: "moveObstacle")
    }
    
    private func startCoins() {
        scheduleNextCoin()
    }
    
    private func scheduleNextCoin() {
        guard gameState == .playing else { return }
        
        let wait = SKAction.wait(forDuration: Double.random(in: 1.5...3.0))
        let spawn = SKAction.run { [weak self] in
            self?.spawnCoin()
            self?.scheduleNextCoin()
        }
        
        run(SKAction.sequence([wait, spawn]), withKey: "coin")
    }
    
    private func spawnCoin() {
        guard gameState == .playing else { return }
        
        let coinName: String
        
        if executionTime < 30 {
            if logSlowModeActive {
                return
            }
            coinName = "coin_log"
        } else {
            if logSlowModeActive {
                coinName = "coin_retry"
            } else {
                coinName = Bool.random() ? "coin_log" : "coin_retry"
            }
        }
        
        let coin = SKSpriteNode(imageNamed: coinName)
        coin.size = CGSize(width: 60, height: 60)
        coin.position = CGPoint(x: size.width + 50, y: coinY)
        coin.zPosition = 12
        coin.name = coinName
        
        coin.physicsBody = SKPhysicsBody(circleOfRadius: 25)
        coin.physicsBody?.isDynamic = false
        coin.physicsBody?.categoryBitMask = coinCategory
        coin.physicsBody?.contactTestBitMask = playerCategory
        coin.physicsBody?.collisionBitMask = 0
        
        addChild(coin)
        
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 0.8)
        coin.run(SKAction.repeatForever(rotate))
        
        let move = SKAction.moveTo(x: -50, duration: 2.5)
        coin.run(SKAction.sequence([move, .removeFromParent()]))
    }
    
    private func collectCoin(_ coin: SKNode) {
        playEffect(named: "coin")
        
        if coin.name == "coin_retry" {
            retry += 1
            retryLabel.text = "Retry: \(retry)"
        }
        
        if coin.name == "coin_log" {
            slowObstaclesTemporarily()
        }
        
        coin.removeFromParent()
    }
    
    private func slowObstaclesTemporarily() {
        if logSlowModeActive {
            return
        }
        
        logSlowModeActive = true
        removeAction(forKey: "slowMode")
        
        enumerateChildNodes(withName: "obstacle") { node, _ in
            node.removeAction(forKey: "moveObstacle")
            
            let remainingDistance = node.position.x + 50
            let screenDistance = self.size.width + 100
            let progressDuration = Double(remainingDistance / screenDistance) * 2.6
            
            let move = SKAction.moveTo(x: -50, duration: max(0.4, progressDuration))
            node.run(SKAction.sequence([move, .removeFromParent()]), withKey: "moveObstacle")
        }
        
        run(SKAction.sequence([
            SKAction.wait(forDuration: logSlowDuration),
            SKAction.run {
                self.logSlowModeActive = false
            }
        ]), withKey: "slowMode")
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        executionTime += deltaTime
        
        moveBackground()
        trySpawnObstacle(currentTime: currentTime)
        updateTimeLabel()
        
        if executionTime >= completedTime {
            showCompleted()
        }
    }
    
    private func updateTimeLabel() {
        let totalSeconds = Int(executionTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        scoreLabel.text = String(format: "Tempo: %02d:%02d", minutes, seconds)
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else { return }
        
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == playerCategory | coinCategory {
            let coin = contact.bodyA.categoryBitMask == coinCategory ? contact.bodyA.node : contact.bodyB.node
            
            if let coin = coin {
                collectCoin(coin)
            }
            
            return
        }
        
        if collision == playerCategory | obstacleCategory {
            playEffect(named: "collision")
            
            if retry > 1 {
                retry -= 1
                retryLabel.text = "Retry: \(retry)"
                removeNearbyObstacles()
            } else {
                showGameOver()
            }
        }
    }
    
    private func removeNearbyObstacles() {
        enumerateChildNodes(withName: "obstacle") { node, _ in
            if abs(node.position.x - self.player.position.x) < 130 {
                node.removeFromParent()
            }
        }
    }
    
    private func showGameOver() {
        gameState = .gameOver
        removeAllActions()
        stopMusic()
        playEffect(named: "game_over")
        
        let bg = SKSpriteNode(imageNamed: "screen_game_over")
        bg.size = size
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = 100
        addChild(bg)
        
        let home = SKSpriteNode(imageNamed: "button_home")
        home.size = CGSize(width: 100, height: 100)
        home.position = CGPoint(x: size.width * 0.4, y: size.height * 0.25)
        home.zPosition = 200
        home.name = "home"
        addChild(home)
        
        let retryButton = SKSpriteNode(imageNamed: "button_retry")
        retryButton.size = CGSize(width: 100, height: 100)
        retryButton.position = CGPoint(x: size.width * 0.6, y: size.height * 0.25)
        retryButton.zPosition = 200
        retryButton.name = "retry"
        addChild(retryButton)
    }
    
    private func showCompleted() {
        gameState = .completed
        removeAllActions()
        stopMusic()
        playEffect(named: "completed")
        
        let bg = SKSpriteNode(imageNamed: "screen_completed")
        bg.size = size
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = 100
        addChild(bg)
        
        let home = SKSpriteNode(imageNamed: "button_home")
        home.size = CGSize(width: 100, height: 100)
        home.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
        home.zPosition = 200
        home.name = "home"
        addChild(home)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let node = atPoint(touch.location(in: self))
        
        if node.name == "play" {
            startGame()
            return
        }
        
        if node.name == "home" {
            showMenu()
            return
        }
        
        if node.name == "retry" {
            startGame()
            return
        }
        
        if gameState == .playing {
            jump()
        }
    }
    
    private func playMusic(named fileName: String, loop: Bool) {
        stopMusic()
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            print("Música não encontrada: \(fileName).mp3")
            return
        }
        
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = loop ? -1 : 0
            musicPlayer?.volume = 0.7
            musicPlayer?.prepareToPlay()
            musicPlayer?.play()
        } catch {
            print("Erro ao tocar música: \(fileName).mp3")
        }
    }
    
    private func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }
    
    private func playEffect(named fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            print("Efeito não encontrado: \(fileName).mp3")
            return
        }
        
        do {
            let effectPlayer = try AVAudioPlayer(contentsOf: url)
            effectPlayer.volume = 1.0
            effectPlayer.prepareToPlay()
            effectPlayer.play()
            
            effectPlayers.append(effectPlayer)
            effectPlayers = effectPlayers.filter { $0.isPlaying }
        } catch {
            print("Erro ao tocar efeito: \(fileName).mp3")
        }
    }
}
