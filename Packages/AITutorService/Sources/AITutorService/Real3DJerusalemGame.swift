import Foundation
import UIKit
import SceneKit
import AVFoundation
import SwiftUI

// MARK: - Real 3D SceneKit Jerusalem Game

class Real3DJerusalemGameViewController: UIViewController {
    var episodeId: String = ""
    weak var bridge: MockUnityBridge?
    
    // Real 3D SceneKit Components
    private var sceneView: SCNView!
    private var scene: SCNScene!
    private var cameraNode: SCNNode!
    private var lightNode: SCNNode!
    private var jerusalemCityNode: SCNNode!
    private var patriarchNode: SCNNode!
    private var commanderNode: SCNNode!
    
    // Game State
    private var isLoading = true
    private var currentSceneName = "city_gates"
    private var playerPosition = SCNVector3(0, 0, 5)
    
    // UI Overlay
    private var uiOverlay: UIView!
    private var loadingLabel: UILabel!
    private var progressView: UIProgressView!
    private var loadingContainer: UIView!
    private var sceneLabel: UILabel!
    private var exitButton: UIButton!
    private var interactionButton: UIButton!
    
    // Game Systems
    private var gameState: GameStateManager!
    private var audioManager: GameAudioManager!
    private var dialogueSystem: DialogueSystem!
    private var questManager: QuestManager!
    
    // UI
    private var gameHUD: UIHostingController<GameHUD>!
    private var currentDialogueView: UIHostingController<DialogueInterface>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🎮 [Real 3D Game] viewDidLoad called")
        
        initializeGameSystems()
        setupReal3DGame()
        
        // For debugging: add option to skip loading screen
        let skipLoading = true // Set to true to skip loading for testing
        
        if skipLoading {
            print("🎮 [Real 3D Game] SKIPPING loading screen for debugging")
            
            // Hide loading UI immediately
            loadingContainer?.alpha = 0
            loadingLabel?.alpha = 0
            progressView?.alpha = 0
            
            // Build scene
            buildCityWalls()
            buildAncientBuildings()
            placeCharacters()
            applyMaterials()
            
            // Start gameplay immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.forceStartGameplay()
            }
        } else {
            loadJerusalemScene()
        }
    }
    
    private func initializeGameSystems() {
        gameState = GameStateManager()
        audioManager = GameAudioManager()
        dialogueSystem = DialogueSystem(gameState: gameState, audioManager: audioManager)
        questManager = QuestManager(gameState: gameState, audioManager: audioManager)
        
        // Initialize main quest
        questManager.initializeMainQuests()
    }
    
    // MARK: - Real 3D Game Setup
    
    private func setupReal3DGame() {
        // Create the SceneKit view
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = UIColor.black
        sceneView.allowsCameraControl = true // Allow user camera control for navigation
        sceneView.showsStatistics = true // Show FPS for realism
        sceneView.antialiasingMode = .multisampling4X
        view.addSubview(sceneView)
        
        // Create the scene
        scene = SCNScene()
        sceneView.scene = scene
        
        // Setup complete game UI
        setupCompleteGameUI()
        
        // Setup traditional overlay UI
        setupUIOverlay()
        
        // Setup lighting
        setupLighting()
        
        // Setup camera
        setupCamera()
        
        // Add gesture recognizers
        setupGestures()
        
        // Enable comprehensive camera controls for navigation
        sceneView.allowsCameraControl = true
        sceneView.cameraControlConfiguration.allowsTranslation = true
        sceneView.cameraControlConfiguration.autoSwitchToFreeCamera = true
        
        // Configure available camera control properties
        if #available(iOS 15.0, *) {
            // Use newer camera control properties if available
            sceneView.cameraControlConfiguration.rotationSensitivity = 1.0
        }
        
        print("🎮 [Real 3D Game] Camera controls enabled - pinch to zoom, drag to rotate, pan to move")
    }
    
    private func setupCompleteGameUI() {
        // Create the main game HUD
        gameHUD = UIHostingController(rootView: GameHUD(gameState: gameState))
        gameHUD.view.backgroundColor = .clear
        gameHUD.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(gameHUD)
        view.addSubview(gameHUD.view)
        gameHUD.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            gameHUD.view.topAnchor.constraint(equalTo: view.topAnchor),
            gameHUD.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameHUD.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameHUD.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Setup initial loading UI
        setupLoadingUI()
    }
    
    private func setupUIOverlay() {
        // UI overlay container
        uiOverlay = UIView(frame: view.bounds)
        uiOverlay.backgroundColor = .clear
        uiOverlay.isUserInteractionEnabled = true
        view.addSubview(uiOverlay)
        
        // Loading screen
        setupLoadingUI()
        
        // Game UI (hidden initially)
        setupGameUI()
        
        print("🎮 [Real 3D Game] UI Overlay setup complete")
    }
    
    private func setupLoadingUI() {
        // Ensure uiOverlay exists
        if uiOverlay == nil {
            uiOverlay = UIView(frame: view.bounds)
            uiOverlay.backgroundColor = .clear
            uiOverlay.isUserInteractionEnabled = true
            view.addSubview(uiOverlay)
        }
        
        loadingContainer = UIView()
        loadingContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        loadingContainer.layer.cornerRadius = 20
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        uiOverlay.addSubview(loadingContainer)
        
        loadingLabel = UILabel()
        loadingLabel.text = "🎮 Loading Real 3D Jerusalem..."
        loadingLabel.textColor = .white
        loadingLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.addSubview(loadingLabel)
        
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = .cyan
        progressView.trackTintColor = .gray
        progressView.layer.cornerRadius = 4
        progressView.layer.shadowColor = UIColor.cyan.cgColor
        progressView.layer.shadowRadius = 10
        progressView.layer.shadowOpacity = 1.0
        progressView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            loadingContainer.centerXAnchor.constraint(equalTo: uiOverlay.centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: uiOverlay.centerYAnchor),
            loadingContainer.widthAnchor.constraint(equalToConstant: 350),
            loadingContainer.heightAnchor.constraint(equalToConstant: 150),
            
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: loadingContainer.topAnchor, constant: 30),
            
            progressView.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            progressView.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 30),
            progressView.widthAnchor.constraint(equalToConstant: 300),
            progressView.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
    
    private func setupGameUI() {
        // Scene title
        sceneLabel = UILabel()
        sceneLabel.text = "🏛️ Jerusalem City Gates - 637 CE"
        sceneLabel.textColor = .white
        sceneLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        sceneLabel.textAlignment = .center
        sceneLabel.alpha = 0
        sceneLabel.layer.shadowColor = UIColor.black.cgColor
        sceneLabel.layer.shadowRadius = 3
        sceneLabel.layer.shadowOpacity = 1.0
        sceneLabel.translatesAutoresizingMaskIntoConstraints = false
        uiOverlay.addSubview(sceneLabel)
        
        // Exit button - FIXED to actually work
        exitButton = UIButton(type: .system)
        exitButton.setTitle("⚡ Exit Game", for: .normal)
        exitButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        exitButton.setTitleColor(.white, for: .normal)
        exitButton.backgroundColor = UIColor.red.withAlphaComponent(0.9)
        exitButton.layer.cornerRadius = 12
        exitButton.layer.shadowColor = UIColor.red.cgColor
        exitButton.layer.shadowRadius = 8
        exitButton.layer.shadowOpacity = 0.8
        exitButton.alpha = 0
        exitButton.addTarget(self, action: #selector(exitGameTapped), for: .touchUpInside)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        uiOverlay.addSubview(exitButton)
        
        // Interaction button
        interactionButton = UIButton(type: .system)
        interactionButton.setTitle("💬 Talk to Patriarch Sophronius", for: .normal)
        interactionButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        interactionButton.setTitleColor(.white, for: .normal)
        interactionButton.backgroundColor = UIColor.blue.withAlphaComponent(0.9)
        interactionButton.layer.cornerRadius = 15
        interactionButton.layer.shadowColor = UIColor.blue.cgColor
        interactionButton.layer.shadowRadius = 10
        interactionButton.layer.shadowOpacity = 0.8
        interactionButton.alpha = 0
        interactionButton.addTarget(self, action: #selector(interactionTapped), for: .touchUpInside)
        interactionButton.translatesAutoresizingMaskIntoConstraints = false
        uiOverlay.addSubview(interactionButton)
        
        NSLayoutConstraint.activate([
            sceneLabel.topAnchor.constraint(equalTo: uiOverlay.safeAreaLayoutGuide.topAnchor, constant: 20),
            sceneLabel.centerXAnchor.constraint(equalTo: uiOverlay.centerXAnchor),
            
            exitButton.topAnchor.constraint(equalTo: uiOverlay.safeAreaLayoutGuide.topAnchor, constant: 20),
            exitButton.trailingAnchor.constraint(equalTo: uiOverlay.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            exitButton.widthAnchor.constraint(equalToConstant: 140),
            exitButton.heightAnchor.constraint(equalToConstant: 44),
            
            interactionButton.centerXAnchor.constraint(equalTo: uiOverlay.centerXAnchor),
            interactionButton.bottomAnchor.constraint(equalTo: uiOverlay.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            interactionButton.widthAnchor.constraint(equalToConstant: 350),
            interactionButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func setupLighting() {
        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.4, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // Directional light (sun)
        lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.color = UIColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1.0)
        lightNode.light?.intensity = 1000
        lightNode.light?.castsShadow = true
        lightNode.light?.shadowMode = .forward
        lightNode.light?.shadowSampleCount = 16
        lightNode.position = SCNVector3(10, 10, 10)
        lightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(lightNode)
        
        // Point light for warm atmosphere
        let pointLight = SCNNode()
        pointLight.light = SCNLight()
        pointLight.light?.type = .omni
        pointLight.light?.color = UIColor.orange
        pointLight.light?.intensity = 500
        pointLight.position = SCNVector3(0, 5, 0)
        scene.rootNode.addChildNode(pointLight)
    }
    
    private func setupCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 75
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 1000
        
        // Position camera for good overview of Jerusalem
        cameraNode.position = SCNVector3(0, 8, 15)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        
        scene.rootNode.addChildNode(cameraNode)
        
        // Set the camera as the point of view
        sceneView.pointOfView = cameraNode
        
        print("🎥 [Real 3D Game] Camera positioned at: \(cameraNode.position)")
    }
    
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - 3D Scene Loading
    
    private func loadJerusalemScene() {
        progressView.progress = 0.0
        loadingLabel.text = "🎮 Loading Real 3D Jerusalem..."
        
        print("🎮 [Real 3D Game] Starting Jerusalem scene loading...")
        
        // Simple, reliable loading sequence
        var progress: Float = 0.0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            progress += 0.2
            self.progressView.progress = progress
            
            switch progress {
            case 0.2:
                self.loadingLabel.text = "🏗️ Building Jerusalem City Walls..."
                self.buildCityWalls()
            case 0.4:
                self.loadingLabel.text = "🏛️ Constructing Ancient Buildings..."
                self.buildAncientBuildings()
            case 0.6:
                self.loadingLabel.text = "👥 Placing Historical Characters..."
                self.placeCharacters()
            case 0.8:
                self.loadingLabel.text = "🎨 Applying Textures and Materials..."
                self.applyMaterials()
            case 1.0:
                self.loadingLabel.text = "✨ Entering Ancient Jerusalem..."
                timer.invalidate()
                
                print("🎮 [Real 3D Game] Scene loading completed, starting gameplay...")
                
                // Try force start first, fallback to regular start
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.forceStartGameplay()
                }
            default:
                break
            }
        }
        
        // Failsafe: Force completion after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            if !timer.isValid { return }
            timer.invalidate()
            print("🎮 [Real 3D Game] FAILSAFE triggered - forcing gameplay start")
            self.forceStartGameplay()
        }
    }
    
    private func buildCityWalls() {
        // Create detailed Jerusalem city walls with realistic stone texture
        createDetailedCityWalls()
        createGateArches()
        createWallTowers()
        createStoneDetails()
    }
    
    private func createDetailedCityWalls() {
        // Main wall segments with realistic proportions
        let wallHeight: Float = 12.0
        let wallThickness: Float = 3.0
        let wallLength: Float = 40.0
        
        // Create stone material
        let stoneMaterial = createStoneMaterial()
        
        // North wall
        let northWall = createWallSegment(width: wallLength, height: wallHeight, depth: wallThickness)
        northWall.geometry?.materials = [stoneMaterial]
        northWall.position = SCNVector3(0, wallHeight/2 - 4, -20)
        scene.rootNode.addChildNode(northWall)
        
        // South wall
        let southWall = createWallSegment(width: wallLength, height: wallHeight, depth: wallThickness)
        southWall.geometry?.materials = [stoneMaterial]
        southWall.position = SCNVector3(0, wallHeight/2 - 4, 20)
        scene.rootNode.addChildNode(southWall)
        
        // East wall
        let eastWall = createWallSegment(width: wallThickness, height: wallHeight, depth: wallLength)
        eastWall.geometry?.materials = [stoneMaterial]
        eastWall.position = SCNVector3(20, wallHeight/2 - 4, 0)
        scene.rootNode.addChildNode(eastWall)
        
        // West wall
        let westWall = createWallSegment(width: wallThickness, height: wallHeight, depth: wallLength)
        westWall.geometry?.materials = [stoneMaterial]
        westWall.position = SCNVector3(-20, wallHeight/2 - 4, 0)
        scene.rootNode.addChildNode(westWall)
    }
    
    private func createWallSegment(width: Float, height: Float, depth: Float) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: 0.2)
        return SCNNode(geometry: geometry)
    }
    
    private func createStoneMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        
        // Create procedural stone texture
        let textureSize = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: textureSize, height: textureSize))
        
        let stoneTexture = renderer.image { context in
            let cgContext = context.cgContext
            
            // Base stone color
            cgContext.setFillColor(UIColor(red: 0.85, green: 0.8, blue: 0.65, alpha: 1.0).cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: textureSize, height: textureSize))
            
            // Add stone blocks pattern
            cgContext.setStrokeColor(UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 1.0).cgColor)
            cgContext.setLineWidth(2)
            
            let blockWidth = textureSize / 8
            let blockHeight = textureSize / 12
            
            for row in 0..<12 {
                for col in 0..<8 {
                    let offset = row % 2 == 0 ? 0 : blockWidth / 2
                    let x = col * blockWidth + offset
                    let y = row * blockHeight
                    
                    let rect = CGRect(x: x, y: y, width: blockWidth, height: blockHeight)
                    cgContext.stroke(rect)
                    
                    // Add weathering spots
                    if arc4random_uniform(4) == 0 {
                        cgContext.setFillColor(UIColor(red: 0.7, green: 0.65, blue: 0.5, alpha: 0.6).cgColor)
                        cgContext.fillEllipse(in: CGRect(x: x + blockWidth/4, y: y + blockHeight/4, 
                                                       width: blockWidth/2, height: blockHeight/2))
                    }
                }
            }
        }
        
        material.diffuse.contents = stoneTexture
        material.roughness.contents = 0.9
        material.normal.intensity = 0.5
        return material
    }
    
    private func createGateArches() {
        // Damascus Gate (north)
        let gateArch = createArchGate()
        gateArch.position = SCNVector3(0, 2, -20)
        scene.rootNode.addChildNode(gateArch)
        
        // Add gate details
        let gateDetails = createGateDetails()
        gateDetails.position = SCNVector3(0, 2, -20)
        scene.rootNode.addChildNode(gateDetails)
    }
    
    private func createArchGate() -> SCNNode {
        let gateNode = SCNNode()
        
        // Create arch opening
        let archGeometry = SCNTorus(ringRadius: 4, pipeRadius: 0.5)
        let archMaterial = createStoneMaterial()
        archGeometry.materials = [archMaterial]
        
        let archNode = SCNNode(geometry: archGeometry)
        archNode.rotation = SCNVector4(1, 0, 0, Float.pi/2)
        archNode.scale = SCNVector3(1, 0.7, 1) // Make it more arch-like
        gateNode.addChildNode(archNode)
        
        // Gate opening
        let openingGeometry = SCNBox(width: 8, height: 6, length: 4, chamferRadius: 0)
        let openingNode = SCNNode(geometry: openingGeometry)
        openingNode.opacity = 0 // Invisible - creates the opening
        gateNode.addChildNode(openingNode)
        
        return gateNode
    }
    
    private func createGateDetails() -> SCNNode {
        let detailsNode = SCNNode()
        
        // Add columns on sides
        for i in 0..<2 {
            let column = createColumn()
            column.position = SCNVector3(Float(i == 0 ? -5 : 5), 0, 0)
            detailsNode.addChildNode(column)
        }
        
        return detailsNode
    }
    
    private func createColumn() -> SCNNode {
        let columnGeometry = SCNCylinder(radius: 0.8, height: 8)
        let columnMaterial = createStoneMaterial()
        columnGeometry.materials = [columnMaterial]
        
        let columnNode = SCNNode(geometry: columnGeometry)
        
        // Add column capital
        let capitalGeometry = SCNBox(width: 2, height: 0.8, length: 2, chamferRadius: 0.1)
        capitalGeometry.materials = [columnMaterial]
        let capitalNode = SCNNode(geometry: capitalGeometry)
        capitalNode.position = SCNVector3(0, 4.4, 0)
        columnNode.addChildNode(capitalNode)
        
        return columnNode
    }
    
    private func createWallTowers() {
        // Corner towers
        let towerPositions = [
            SCNVector3(-18, 6, -18), // Northwest
            SCNVector3(18, 6, -18),  // Northeast
            SCNVector3(-18, 6, 18),  // Southwest
            SCNVector3(18, 6, 18)    // Southeast
        ]
        
        for position in towerPositions {
            let tower = createTower()
            tower.position = position
            scene.rootNode.addChildNode(tower)
        }
    }
    
    private func createTower() -> SCNNode {
        let towerNode = SCNNode()
        
        // Main tower body
        let towerGeometry = SCNCylinder(radius: 3, height: 16)
        let towerMaterial = createStoneMaterial()
        towerGeometry.materials = [towerMaterial]
        
        let tower = SCNNode(geometry: towerGeometry)
        towerNode.addChildNode(tower)
        
        // Tower top (crenellations)
        for i in 0..<8 {
            let angle = Float(i) * Float.pi * 2 / 8
            let crenellation = SCNBox(width: 1, height: 2, length: 0.5, chamferRadius: 0.1)
            crenellation.materials = [towerMaterial]
            
            let crenNode = SCNNode(geometry: crenellation)
            crenNode.position = SCNVector3(
                3.5 * cos(angle),
                9,
                3.5 * sin(angle)
            )
            towerNode.addChildNode(crenNode)
        }
        
        // Arrow slits
        for i in 0..<4 {
            let angle = Float(i) * Float.pi * 2 / 4
            let slit = createArrowSlit()
            slit.position = SCNVector3(
                3.2 * cos(angle),
                Float.random(in: 2...6),
                3.2 * sin(angle)
            )
            slit.rotation = SCNVector4(0, 1, 0, angle)
            towerNode.addChildNode(slit)
        }
        
        return towerNode
    }
    
    private func createArrowSlit() -> SCNNode {
        let slitGeometry = SCNBox(width: 0.2, height: 1.5, length: 1, chamferRadius: 0.05)
        let slitMaterial = SCNMaterial()
        slitMaterial.diffuse.contents = UIColor.black
        slitGeometry.materials = [slitMaterial]
        
        return SCNNode(geometry: slitGeometry)
    }
    
    private func createStoneDetails() {
        // Add random stone debris and details on the ground
        for _ in 0..<20 {
            let debris = createStoneDebris()
            debris.position = SCNVector3(
                Float.random(in: -15...15),
                -4,
                Float.random(in: -15...15)
            )
            scene.rootNode.addChildNode(debris)
        }
    }
    
    private func createStoneDebris() -> SCNNode {
        let size = Float.random(in: 0.3...0.8)
        let debrisGeometry = SCNBox(width: CGFloat(size), height: CGFloat(size * 0.3), length: CGFloat(size * 0.7), chamferRadius: 0.05)
        let debrisMaterial = createStoneMaterial()
        debrisGeometry.materials = [debrisMaterial]
        
        let debrisNode = SCNNode(geometry: debrisGeometry)
        debrisNode.rotation = SCNVector4(0, 1, 0, Float.random(in: 0...Float.pi * 2))
        return debrisNode
    }
    
    private func buildAncientBuildings() {
        jerusalemCityNode = SCNNode()
        scene.rootNode.addChildNode(jerusalemCityNode)
        
        // Create the Church of the Holy Sepulchre
        let holySepulchre = createHolySepulchre()
        holySepulchre.position = SCNVector3(-8, 0, -5)
        jerusalemCityNode.addChildNode(holySepulchre)
        
        // Create traditional Jerusalem houses
        createJerusalemHouses()
        
        // Create market area
        createMarketArea()
        
        // Create detailed ground with cobblestones
        createCobblestonePlaza()
        
        // Create olive trees and vegetation
        createVegetation()
    }
    
    private func createHolySepulchre() -> SCNNode {
        let churchNode = SCNNode()
        
        // Main church building
        let mainBuilding = SCNBox(width: 12, height: 10, length: 16, chamferRadius: 0.3)
        let churchMaterial = createChurchStoneMaterial()
        mainBuilding.materials = [churchMaterial]
        
        let mainBuildingNode = SCNNode(geometry: mainBuilding)
        mainBuildingNode.position = SCNVector3(0, 1, 0)
        churchNode.addChildNode(mainBuildingNode)
        
        // Dome
        let dome = SCNSphere(radius: 4)
        let domeMaterial = SCNMaterial()
        domeMaterial.diffuse.contents = UIColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 1.0)
        domeMaterial.metalness.contents = 0.3
        dome.materials = [domeMaterial]
        
        let domeNode = SCNNode(geometry: dome)
        domeNode.position = SCNVector3(0, 8, 0)
        domeNode.scale = SCNVector3(1, 0.7, 1)
        churchNode.addChildNode(domeNode)
        
        // Bell tower
        let tower = SCNBox(width: 3, height: 15, length: 3, chamferRadius: 0.2)
        tower.materials = [churchMaterial]
        let towerNode = SCNNode(geometry: tower)
        towerNode.position = SCNVector3(5, 3.5, -6)
        churchNode.addChildNode(towerNode)
        
        // Cross on top
        let cross = createCross()
        cross.position = SCNVector3(5, 11.5, -6)
        churchNode.addChildNode(cross)
        
        // Church entrance with arches
        let entrance = createChurchEntrance()
        entrance.position = SCNVector3(0, 0, 8.5)
        churchNode.addChildNode(entrance)
        
        return churchNode
    }
    
    private func createChurchStoneMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        
        // Create aged stone texture for the church
        let textureSize = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: textureSize, height: textureSize))
        
        let texture = renderer.image { context in
            let cgContext = context.cgContext
            
            // Aged limestone base
            cgContext.setFillColor(UIColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 1.0).cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: textureSize, height: textureSize))
            
            // Add wear patterns
            cgContext.setBlendMode(.multiply)
            for _ in 0..<50 {
                let x = Int.random(in: 0..<textureSize)
                let y = Int.random(in: 0..<textureSize)
                let size = Int.random(in: 20...60)
                
                cgContext.setFillColor(UIColor(red: 0.8, green: 0.75, blue: 0.65, alpha: 0.3).cgColor)
                cgContext.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
            }
        }
        
        material.diffuse.contents = texture
        material.roughness.contents = 0.8
        material.normal.intensity = 0.3
        return material
    }
    
    private func createCross() -> SCNNode {
        let crossNode = SCNNode()
        
        // Vertical beam
        let vertical = SCNBox(width: 0.3, height: 2, length: 0.3, chamferRadius: 0.05)
        let crossMaterial = SCNMaterial()
        crossMaterial.diffuse.contents = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
        vertical.materials = [crossMaterial]
        
        let verticalNode = SCNNode(geometry: vertical)
        crossNode.addChildNode(verticalNode)
        
        // Horizontal beam
        let horizontal = SCNBox(width: 1.2, height: 0.3, length: 0.3, chamferRadius: 0.05)
        horizontal.materials = [crossMaterial]
        let horizontalNode = SCNNode(geometry: horizontal)
        horizontalNode.position = SCNVector3(0, 0.5, 0)
        crossNode.addChildNode(horizontalNode)
        
        return crossNode
    }
    
    private func createChurchEntrance() -> SCNNode {
        let entranceNode = SCNNode()
        
        // Arched doorway
        let archway = createArchway(width: 4, height: 6)
        entranceNode.addChildNode(archway)
        
        // Steps
        for i in 0..<3 {
            let step = SCNBox(width: 5, height: 0.3, length: 1, chamferRadius: 0.05)
            let stepMaterial = createStoneMaterial()
            step.materials = [stepMaterial]
            
            let stepNode = SCNNode(geometry: step)
            stepNode.position = SCNVector3(0, Float(i) * 0.3 - 0.5, Float(i) * 0.5)
            entranceNode.addChildNode(stepNode)
        }
        
        return entranceNode
    }
    
    private func createArchway(width: Float, height: Float) -> SCNNode {
        let archNode = SCNNode()
        
        // Create arch using multiple segments
        let segments = 12
        let radius = width / 2
        
        for i in 0..<segments {
            let angle = Float(i) * Float.pi / Float(segments - 1)
            let segmentWidth: Float = 0.5
            let segmentHeight: Float = 0.3
            
            let segment = SCNBox(width: CGFloat(segmentWidth), height: CGFloat(segmentHeight), length: 1, chamferRadius: 0.05)
            let archMaterial = createChurchStoneMaterial()
            segment.materials = [archMaterial]
            
            let segmentNode = SCNNode(geometry: segment)
            segmentNode.position = SCNVector3(
                radius * cos(angle),
                radius * sin(angle) + height/2 - radius,
                0
            )
            segmentNode.rotation = SCNVector4(0, 0, 1, angle)
            archNode.addChildNode(segmentNode)
        }
        
        return archNode
    }
    
    private func createJerusalemHouses() {
        let housePositions = [
            SCNVector3(10, 0, 5), SCNVector3(-15, 0, 8), SCNVector3(8, 0, -12),
            SCNVector3(-5, 0, 10), SCNVector3(15, 0, -8), SCNVector3(-12, 0, -15)
        ]
        
        for (index, position) in housePositions.enumerated() {
            let house = createTraditionalHouse(type: index % 3)
            house.position = position
            jerusalemCityNode.addChildNode(house)
        }
    }
    
    private func createTraditionalHouse(type: Int) -> SCNNode {
        let houseNode = SCNNode()
        
        // House dimensions
        let width: Float = Float.random(in: 4...7)
        let height: Float = Float.random(in: 4...6)
        let depth: Float = Float.random(in: 4...6)
        
        // Main structure
        let houseGeometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: 0.2)
        let houseMaterial = createHouseMaterial(type: type)
        houseGeometry.materials = [houseMaterial]
        
        let houseMainNode = SCNNode(geometry: houseGeometry)
        houseMainNode.position = SCNVector3(0, height/2 - 2, 0)
        houseNode.addChildNode(houseMainNode)
        
        // Flat roof (traditional Jerusalem style)
        let roofGeometry = SCNBox(width: CGFloat(width + 0.5), height: 0.3, length: CGFloat(depth + 0.5), chamferRadius: 0.1)
        let roofMaterial = SCNMaterial()
        roofMaterial.diffuse.contents = UIColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 1.0)
        roofGeometry.materials = [roofMaterial]
        
        let roofNode = SCNNode(geometry: roofGeometry)
        roofNode.position = SCNVector3(0, height - 1.85, 0)
        houseNode.addChildNode(roofNode)
        
        // Windows
        addWindowsToHouse(houseNode, width: width, height: height, depth: depth)
        
        // Door
        let door = createDoor()
        door.position = SCNVector3(0, height/2 - 3, depth/2 + 0.05)
        houseNode.addChildNode(door)
        
        return houseNode
    }
    
    private func createHouseMaterial(type: Int) -> SCNMaterial {
        let material = SCNMaterial()
        
        let colors = [
            UIColor(red: 0.9, green: 0.85, blue: 0.75, alpha: 1.0), // Limestone white
            UIColor(red: 0.85, green: 0.8, blue: 0.65, alpha: 1.0), // Sandy beige
            UIColor(red: 0.8, green: 0.75, blue: 0.6, alpha: 1.0)   // Warm stone
        ]
        
        material.diffuse.contents = colors[type]
        material.roughness.contents = 0.8
        return material
    }
    
    private func addWindowsToHouse(_ houseNode: SCNNode, width: Float, height: Float, depth: Float) {
        let windowPositions = [
            SCNVector3(-width/3, height/2 - 3, depth/2 + 0.02),
            SCNVector3(width/3, height/2 - 3, depth/2 + 0.02),
            SCNVector3(width/2 + 0.02, height/2 - 3, 0)
        ]
        
        for position in windowPositions {
            let window = createWindow()
            window.position = position
            houseNode.addChildNode(window)
        }
    }
    
    private func createWindow() -> SCNNode {
        let windowNode = SCNNode()
        
        // Window frame
        let frameGeometry = SCNBox(width: 1.2, height: 1.5, length: 0.1, chamferRadius: 0.05)
        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        frameGeometry.materials = [frameMaterial]
        
        let frameNode = SCNNode(geometry: frameGeometry)
        windowNode.addChildNode(frameNode)
        
        // Glass (semi-transparent)
        let glassGeometry = SCNBox(width: 1.0, height: 1.3, length: 0.02, chamferRadius: 0)
        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = UIColor(white: 0.9, alpha: 0.3)
        glassMaterial.transparency = 0.3
        glassGeometry.materials = [glassMaterial]
        
        let glassNode = SCNNode(geometry: glassGeometry)
        windowNode.addChildNode(glassNode)
        
        return windowNode
    }
    
    private func createDoor() -> SCNNode {
        let doorNode = SCNNode()
        
        // Door frame
        let frameGeometry = SCNBox(width: 1.2, height: 2.2, length: 0.1, chamferRadius: 0.05)
        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        frameGeometry.materials = [frameMaterial]
        
        let frameNode = SCNNode(geometry: frameGeometry)
        doorNode.addChildNode(frameNode)
        
        // Door panel
        let doorGeometry = SCNBox(width: 1.0, height: 2.0, length: 0.05, chamferRadius: 0.02)
        let doorMaterial = SCNMaterial()
        doorMaterial.diffuse.contents = UIColor(red: 0.5, green: 0.3, blue: 0.2, alpha: 1.0)
        doorGeometry.materials = [doorMaterial]
        
        let doorPanelNode = SCNNode(geometry: doorGeometry)
        doorNode.addChildNode(doorPanelNode)
        
        return doorNode
    }
    
    private func createMarketArea() {
        let marketNode = SCNNode()
        marketNode.position = SCNVector3(12, 0, 8)
        jerusalemCityNode.addChildNode(marketNode)
        
        // Market stalls
        for i in 0..<4 {
            let stall = createMarketStall()
            stall.position = SCNVector3(Float(i) * 3 - 4.5, 0, 0)
            marketNode.addChildNode(stall)
        }
        
        // Water well
        let well = createWell()
        well.position = SCNVector3(0, 0, -3)
        marketNode.addChildNode(well)
    }
    
    private func createMarketStall() -> SCNNode {
        let stallNode = SCNNode()
        
        // Stall frame
        let posts = [
            SCNVector3(-1, 1.5, -1), SCNVector3(1, 1.5, -1),
            SCNVector3(-1, 1.5, 1), SCNVector3(1, 1.5, 1)
        ]
        
        for post in posts {
            let postGeometry = SCNCylinder(radius: 0.1, height: 3)
            let postMaterial = SCNMaterial()
            postMaterial.diffuse.contents = UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
            postGeometry.materials = [postMaterial]
            
            let postNode = SCNNode(geometry: postGeometry)
            postNode.position = post
            stallNode.addChildNode(postNode)
        }
        
        // Awning
        let awningGeometry = SCNBox(width: 2.5, height: 0.1, length: 2.5, chamferRadius: 0)
        let awningMaterial = SCNMaterial()
        awningMaterial.diffuse.contents = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
        awningGeometry.materials = [awningMaterial]
        
        let awningNode = SCNNode(geometry: awningGeometry)
        awningNode.position = SCNVector3(0, 3, 0)
        stallNode.addChildNode(awningNode)
        
        return stallNode
    }
    
    private func createWell() -> SCNNode {
        let wellNode = SCNNode()
        
        // Well base
        let wellGeometry = SCNCylinder(radius: 1.5, height: 1)
        let wellMaterial = createStoneMaterial()
        wellGeometry.materials = [wellMaterial]
        
        let wellBase = SCNNode(geometry: wellGeometry)
        wellBase.position = SCNVector3(0, -1.5, 0)
        wellNode.addChildNode(wellBase)
        
        // Well frame
        let frameGeometry = SCNCylinder(radius: 1.7, height: 0.3)
        frameGeometry.materials = [wellMaterial]
        let frameNode = SCNNode(geometry: frameGeometry)
        frameNode.position = SCNVector3(0, -0.85, 0)
        wellNode.addChildNode(frameNode)
        
        return wellNode
    }
    
    private func createCobblestonePlaza() {
        let plazaSize: Float = 60
        let cobblestoneTexture = createCobblestoneTexture()
        
        let plazaGeometry = SCNPlane(width: CGFloat(plazaSize), height: CGFloat(plazaSize))
        let plazaMaterial = SCNMaterial()
        plazaMaterial.diffuse.contents = cobblestoneTexture
        plazaMaterial.normal.contents = cobblestoneTexture
        plazaMaterial.normal.intensity = 0.3
        plazaGeometry.materials = [plazaMaterial]
        
        let plazaNode = SCNNode(geometry: plazaGeometry)
        plazaNode.rotation = SCNVector4(1, 0, 0, -Float.pi / 2)
        plazaNode.position = SCNVector3(0, -4, 0)
        scene.rootNode.addChildNode(plazaNode)
    }
    
    private func createCobblestoneTexture() -> UIImage {
        let textureSize = 1024
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: textureSize, height: textureSize))
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Base color
            cgContext.setFillColor(UIColor(red: 0.7, green: 0.65, blue: 0.55, alpha: 1.0).cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: textureSize, height: textureSize))
            
            // Draw cobblestones
            let stoneSize = 30
            let rows = textureSize / stoneSize
            let cols = textureSize / stoneSize
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = col * stoneSize + Int.random(in: -3...3)
                    let y = row * stoneSize + Int.random(in: -3...3)
                    let size = stoneSize + Int.random(in: -5...5)
                    
                    // Stone color variation
                    let variation = Float.random(in: -0.1...0.1)
                    cgContext.setFillColor(UIColor(
                        red: CGFloat(0.7 + variation),
                        green: CGFloat(0.65 + variation),
                        blue: CGFloat(0.55 + variation),
                        alpha: 1.0
                    ).cgColor)
                    
                    cgContext.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
                    
                    // Stone outline
                    cgContext.setStrokeColor(UIColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 1.0).cgColor)
                    cgContext.setLineWidth(1)
                    cgContext.strokeEllipse(in: CGRect(x: x, y: y, width: size, height: size))
                }
            }
        }
    }
    
    private func createVegetation() {
        // Olive trees
        let treePositions = [
            SCNVector3(-10, 0, 15), SCNVector3(15, 0, 12), SCNVector3(-8, 0, -18),
            SCNVector3(12, 0, -15), SCNVector3(-18, 0, 5)
        ]
        
        for position in treePositions {
            let tree = createOliveTree()
            tree.position = position
            scene.rootNode.addChildNode(tree)
        }
        
        // Bushes and small plants
        for _ in 0..<15 {
            let plant = createBush()
            plant.position = SCNVector3(
                Float.random(in: -18...18),
                -3.5,
                Float.random(in: -18...18)
            )
            scene.rootNode.addChildNode(plant)
        }
    }
    
    private func createOliveTree() -> SCNNode {
        let treeNode = SCNNode()
        
        // Trunk
        let trunkGeometry = SCNCylinder(radius: 0.3, height: 4)
        let trunkMaterial = SCNMaterial()
        trunkMaterial.diffuse.contents = UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        trunkGeometry.materials = [trunkMaterial]
        
        let trunkNode = SCNNode(geometry: trunkGeometry)
        trunkNode.position = SCNVector3(0, 0, 0)
        treeNode.addChildNode(trunkNode)
        
        // Foliage (multiple spheres for natural look)
        let foliagePositions = [
            SCNVector3(0, 3, 0), SCNVector3(-1, 2.5, 0.5), SCNVector3(1, 2.8, -0.5),
            SCNVector3(0.5, 3.2, 1), SCNVector3(-0.8, 3.1, -0.8)
        ]
        
        for position in foliagePositions {
            let foliageGeometry = SCNSphere(radius: CGFloat(Float.random(in: 1.0...1.8)))
            let foliageMaterial = SCNMaterial()
            foliageMaterial.diffuse.contents = UIColor(red: 0.3, green: 0.5, blue: 0.2, alpha: 1.0)
            foliageGeometry.materials = [foliageMaterial]
            
            let foliageNode = SCNNode(geometry: foliageGeometry)
            foliageNode.position = position
            treeNode.addChildNode(foliageNode)
        }
        
        return treeNode
    }
    
    private func createBush() -> SCNNode {
        let bushGeometry = SCNSphere(radius: CGFloat(Float.random(in: 0.5...1.2)))
        let bushMaterial = SCNMaterial()
        bushMaterial.diffuse.contents = UIColor(red: 0.2, green: 0.4, blue: 0.1, alpha: 1.0)
        bushGeometry.materials = [bushMaterial]
        
        let bushNode = SCNNode(geometry: bushGeometry)
        bushNode.scale = SCNVector3(1, 0.7, 1) // Flatten slightly
        
        return bushNode
    }
    
    private func placeCharacters() {
        // Patriarch Sophronius - realistic human character
        patriarchNode = createPatriarch()
        patriarchNode.position = SCNVector3(-3, -2.5, -5)
        scene.rootNode.addChildNode(patriarchNode)
        
        // Commander Khalid - realistic military character
        commanderNode = createCommander()
        commanderNode.position = SCNVector3(3, -2.5, -5)
        scene.rootNode.addChildNode(commanderNode)
        
        // Add crowd of people
        createCrowdOfPeople()
    }
    
    private func createPatriarch() -> SCNNode {
        let patriarchNode = SCNNode()
        
        // Body (torso)
        let torsoGeometry = SCNCapsule(capRadius: 0.4, height: 1.2)
        let robesMaterial = SCNMaterial()
        robesMaterial.diffuse.contents = UIColor(red: 0.2, green: 0.1, blue: 0.4, alpha: 1.0) // Purple robes
        robesMaterial.roughness.contents = 0.8
        torsoGeometry.materials = [robesMaterial]
        
        let torsoNode = SCNNode(geometry: torsoGeometry)
        torsoNode.position = SCNVector3(0, 0.6, 0)
        patriarchNode.addChildNode(torsoNode)
        
        // Head
        let headGeometry = SCNSphere(radius: 0.25)
        let skinMaterial = SCNMaterial()
        skinMaterial.diffuse.contents = UIColor(red: 0.92, green: 0.8, blue: 0.7, alpha: 1.0)
        skinMaterial.roughness.contents = 0.6
        headGeometry.materials = [skinMaterial]
        
        let headNode = SCNNode(geometry: headGeometry)
        headNode.position = SCNVector3(0, 1.5, 0)
        patriarchNode.addChildNode(headNode)
        
        // Beard
        let beardGeometry = SCNSphere(radius: 0.15)
        let beardMaterial = SCNMaterial()
        beardMaterial.diffuse.contents = UIColor(white: 0.8, alpha: 1.0)
        beardGeometry.materials = [beardMaterial]
        
        let beardNode = SCNNode(geometry: beardGeometry)
        beardNode.position = SCNVector3(0, 1.35, 0.15)
        beardNode.scale = SCNVector3(1, 0.6, 1.2)
        patriarchNode.addChildNode(beardNode)
        
        // Bishop's hat (mitre)
        let hatGeometry = SCNCone(topRadius: 0, bottomRadius: 0.2, height: 0.4)
        let hatMaterial = SCNMaterial()
        hatMaterial.diffuse.contents = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        hatGeometry.materials = [hatMaterial]
        
        let hatNode = SCNNode(geometry: hatGeometry)
        hatNode.position = SCNVector3(0, 1.9, 0)
        patriarchNode.addChildNode(hatNode)
        
        // Arms
        for i in 0..<2 {
            let armGeometry = SCNCapsule(capRadius: 0.12, height: 0.8)
            armGeometry.materials = [robesMaterial]
            
            let armNode = SCNNode(geometry: armGeometry)
            armNode.position = SCNVector3(Float(i == 0 ? -0.5 : 0.5), 0.8, 0)
            armNode.rotation = SCNVector4(0, 0, 1, Float(i == 0 ? 0.3 : -0.3))
            patriarchNode.addChildNode(armNode)
            
            // Hands
            let handGeometry = SCNSphere(radius: 0.08)
            handGeometry.materials = [skinMaterial]
            let handNode = SCNNode(geometry: handGeometry)
            handNode.position = SCNVector3(Float(i == 0 ? -0.8 : 0.8), 0.4, 0.1)
            patriarchNode.addChildNode(handNode)
        }
        
        // Staff
        let staffGeometry = SCNCylinder(radius: 0.03, height: 2.5)
        let staffMaterial = SCNMaterial()
        staffMaterial.diffuse.contents = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
        staffGeometry.materials = [staffMaterial]
        
        let staffNode = SCNNode(geometry: staffGeometry)
        staffNode.position = SCNVector3(-0.9, 0.8, 0)
        staffNode.rotation = SCNVector4(0, 0, 1, 0.2)
        patriarchNode.addChildNode(staffNode)
        
        // Cross on staff
        let staffCross = createCross()
        staffCross.position = SCNVector3(-1.1, 2.2, 0)
        staffCross.scale = SCNVector3(0.3, 0.3, 0.3)
        patriarchNode.addChildNode(staffCross)
        
        // Legs
        for i in 0..<2 {
            let legGeometry = SCNCapsule(capRadius: 0.15, height: 1.0)
            legGeometry.materials = [robesMaterial]
            
            let legNode = SCNNode(geometry: legGeometry)
            legNode.position = SCNVector3(Float(i == 0 ? -0.2 : 0.2), -0.5, 0)
            patriarchNode.addChildNode(legNode)
        }
        
        // Gentle swaying animation
        let swayAction = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.1, z: 0, duration: 4),
                SCNAction.rotateBy(x: 0, y: -0.2, z: 0, duration: 8),
                SCNAction.rotateBy(x: 0, y: 0.1, z: 0, duration: 4)
            ])
        )
        patriarchNode.runAction(swayAction)
        
        return patriarchNode
    }
    
    private func createCommander() -> SCNNode {
        let commanderNode = SCNNode()
        
        // Body (armored)
        let torsoGeometry = SCNCapsule(capRadius: 0.45, height: 1.3)
        let armorMaterial = SCNMaterial()
        armorMaterial.diffuse.contents = UIColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 1.0) // Chainmail/leather
        armorMaterial.metalness.contents = 0.3
        armorMaterial.roughness.contents = 0.7
        torsoGeometry.materials = [armorMaterial]
        
        let torsoNode = SCNNode(geometry: torsoGeometry)
        torsoNode.position = SCNVector3(0, 0.65, 0)
        commanderNode.addChildNode(torsoNode)
        
        // Head
        let headGeometry = SCNSphere(radius: 0.25)
        let skinMaterial = SCNMaterial()
        skinMaterial.diffuse.contents = UIColor(red: 0.85, green: 0.7, blue: 0.6, alpha: 1.0)
        skinMaterial.roughness.contents = 0.6
        headGeometry.materials = [skinMaterial]
        
        let headNode = SCNNode(geometry: headGeometry)
        headNode.position = SCNVector3(0, 1.55, 0)
        commanderNode.addChildNode(headNode)
        
        // Helmet
        let helmetGeometry = SCNSphere(radius: 0.28)
        let helmetMaterial = SCNMaterial()
        helmetMaterial.diffuse.contents = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        helmetMaterial.metalness.contents = 0.8
        helmetMaterial.roughness.contents = 0.2
        helmetGeometry.materials = [helmetMaterial]
        
        let helmetNode = SCNNode(geometry: helmetGeometry)
        helmetNode.position = SCNVector3(0, 1.6, 0)
        helmetNode.scale = SCNVector3(1, 0.8, 1)
        commanderNode.addChildNode(helmetNode)
        
        // Beard
        let beardGeometry = SCNSphere(radius: 0.12)
        let beardMaterial = SCNMaterial()
        beardMaterial.diffuse.contents = UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        beardGeometry.materials = [beardMaterial]
        
        let beardNode = SCNNode(geometry: beardGeometry)
        beardNode.position = SCNVector3(0, 1.4, 0.18)
        beardNode.scale = SCNVector3(1, 0.5, 1.2)
        commanderNode.addChildNode(beardNode)
        
        // Arms with armor
        for i in 0..<2 {
            let armGeometry = SCNCapsule(capRadius: 0.14, height: 0.9)
            armGeometry.materials = [armorMaterial]
            
            let armNode = SCNNode(geometry: armGeometry)
            armNode.position = SCNVector3(Float(i == 0 ? -0.6 : 0.6), 0.9, 0)
            armNode.rotation = SCNVector4(0, 0, 1, Float(i == 0 ? 0.2 : -0.2))
            commanderNode.addChildNode(armNode)
            
            // Gauntlets
            let gauntletGeometry = SCNBox(width: 0.2, height: 0.15, length: 0.3, chamferRadius: 0.02)
            gauntletGeometry.materials = [helmetMaterial]
            let gauntletNode = SCNNode(geometry: gauntletGeometry)
            gauntletNode.position = SCNVector3(Float(i == 0 ? -0.85 : 0.85), 0.45, 0.1)
            commanderNode.addChildNode(gauntletNode)
        }
        
        // Sword
        let swordHandle = SCNCylinder(radius: 0.04, height: 0.8)
        let swordMaterial = SCNMaterial()
        swordMaterial.diffuse.contents = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
        swordHandle.materials = [swordMaterial]
        
        let swordNode = SCNNode(geometry: swordHandle)
        swordNode.position = SCNVector3(0.5, 0.5, -0.3)
        swordNode.rotation = SCNVector4(1, 0, 0, -0.3)
        commanderNode.addChildNode(swordNode)
        
        // Sword blade
        let bladeGeometry = SCNBox(width: 0.08, height: 1.2, length: 0.02, chamferRadius: 0.01)
        bladeGeometry.materials = [helmetMaterial]
        let bladeNode = SCNNode(geometry: bladeGeometry)
        bladeNode.position = SCNVector3(0.5, 1.1, -0.25)
        bladeNode.rotation = SCNVector4(1, 0, 0, -0.3)
        commanderNode.addChildNode(bladeNode)
        
        // Legs with armor
        for i in 0..<2 {
            let legGeometry = SCNCapsule(capRadius: 0.18, height: 1.1)
            legGeometry.materials = [armorMaterial]
            
            let legNode = SCNNode(geometry: legGeometry)
            legNode.position = SCNVector3(Float(i == 0 ? -0.25 : 0.25), -0.55, 0)
            commanderNode.addChildNode(legNode)
            
            // Boots
            let bootGeometry = SCNBox(width: 0.3, height: 0.15, length: 0.4, chamferRadius: 0.05)
            let bootMaterial = SCNMaterial()
            bootMaterial.diffuse.contents = UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
            bootGeometry.materials = [bootMaterial]
            
            let bootNode = SCNNode(geometry: bootGeometry)
            bootNode.position = SCNVector3(Float(i == 0 ? -0.25 : 0.25), -1.15, 0.1)
            commanderNode.addChildNode(bootNode)
        }
        
        // Shield
        let shieldGeometry = SCNCylinder(radius: 0.6, height: 0.1)
        let shieldMaterial = SCNMaterial()
        shieldMaterial.diffuse.contents = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
        shieldGeometry.materials = [shieldMaterial]
        
        let shieldNode = SCNNode(geometry: shieldGeometry)
        shieldNode.position = SCNVector3(-0.7, 0.8, 0)
        shieldNode.rotation = SCNVector4(0, 1, 0, 0.3)
        commanderNode.addChildNode(shieldNode)
        
        // Alert stance animation
        let alertAction = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.rotateBy(x: 0.05, y: 0, z: 0, duration: 2),
                SCNAction.rotateBy(x: -0.1, y: 0, z: 0, duration: 4),
                SCNAction.rotateBy(x: 0.05, y: 0, z: 0, duration: 2)
            ])
        )
        commanderNode.runAction(alertAction)
        
        return commanderNode
    }
    
    private func createCrowdOfPeople() {
        let crowdPositions = [
            SCNVector3(-8, -2.5, -8), SCNVector3(6, -2.5, -10), SCNVector3(-5, -2.5, 12),
            SCNVector3(10, -2.5, 8), SCNVector3(-12, -2.5, 5), SCNVector3(8, -2.5, -15),
            SCNVector3(-10, -2.5, -12), SCNVector3(12, -2.5, -8)
        ]
        
        for (index, position) in crowdPositions.enumerated() {
            let person = createPerson(type: index % 4)
            person.position = position
            scene.rootNode.addChildNode(person)
        }
    }
    
    private func createPerson(type: Int) -> SCNNode {
        let personNode = SCNNode()
        
        // Different clothing colors and styles
        let clothingColors = [
            UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0), // Brown
            UIColor(red: 0.3, green: 0.5, blue: 0.2, alpha: 1.0), // Green
            UIColor(red: 0.5, green: 0.3, blue: 0.1, alpha: 1.0), // Dark brown
            UIColor(red: 0.4, green: 0.4, blue: 0.6, alpha: 1.0)  // Blue-grey
        ]
        
        let skinColors = [
            UIColor(red: 0.92, green: 0.8, blue: 0.7, alpha: 1.0),
            UIColor(red: 0.85, green: 0.7, blue: 0.6, alpha: 1.0),
            UIColor(red: 0.78, green: 0.65, blue: 0.55, alpha: 1.0)
        ]
        
        // Body
        let torsoGeometry = SCNCapsule(capRadius: 0.35, height: 1.1)
        let clothingMaterial = SCNMaterial()
        clothingMaterial.diffuse.contents = clothingColors[type]
        clothingMaterial.roughness.contents = 0.8
        torsoGeometry.materials = [clothingMaterial]
        
        let torsoNode = SCNNode(geometry: torsoGeometry)
        torsoNode.position = SCNVector3(0, 0.55, 0)
        personNode.addChildNode(torsoNode)
        
        // Head
        let headGeometry = SCNSphere(radius: 0.22)
        let skinMaterial = SCNMaterial()
        skinMaterial.diffuse.contents = skinColors[min(type, skinColors.count - 1)]
        skinMaterial.roughness.contents = 0.6
        headGeometry.materials = [skinMaterial]
        
        let headNode = SCNNode(geometry: headGeometry)
        headNode.position = SCNVector3(0, 1.32, 0)
        personNode.addChildNode(headNode)
        
        // Hair/head covering
        if type % 2 == 0 {
            // Hair
            let hairGeometry = SCNSphere(radius: 0.24)
            let hairMaterial = SCNMaterial()
            hairMaterial.diffuse.contents = UIColor(red: 0.2, green: 0.1, blue: 0.05, alpha: 1.0)
            hairGeometry.materials = [hairMaterial]
            
            let hairNode = SCNNode(geometry: hairGeometry)
            hairNode.position = SCNVector3(0, 1.4, 0)
            hairNode.scale = SCNVector3(1, 0.6, 1)
            personNode.addChildNode(hairNode)
        } else {
            // Head covering
            let coveringGeometry = SCNSphere(radius: 0.26)
            let coveringMaterial = SCNMaterial()
            coveringMaterial.diffuse.contents = clothingColors[(type + 1) % clothingColors.count]
            coveringGeometry.materials = [coveringMaterial]
            
            let coveringNode = SCNNode(geometry: coveringGeometry)
            coveringNode.position = SCNVector3(0, 1.4, 0)
            coveringNode.scale = SCNVector3(1, 0.5, 1)
            personNode.addChildNode(coveringNode)
        }
        
        // Arms
        for i in 0..<2 {
            let armGeometry = SCNCapsule(capRadius: 0.1, height: 0.7)
            armGeometry.materials = [clothingMaterial]
            
            let armNode = SCNNode(geometry: armGeometry)
            armNode.position = SCNVector3(Float(i == 0 ? -0.45 : 0.45), 0.75, 0)
            armNode.rotation = SCNVector4(0, 0, 1, Float(i == 0 ? 0.1 : -0.1))
            personNode.addChildNode(armNode)
        }
        
        // Legs
        for i in 0..<2 {
            let legGeometry = SCNCapsule(capRadius: 0.12, height: 0.9)
            legGeometry.materials = [clothingMaterial]
            
            let legNode = SCNNode(geometry: legGeometry)
            legNode.position = SCNVector3(Float(i == 0 ? -0.15 : 0.15), -0.45, 0)
            personNode.addChildNode(legNode)
        }
        
        // Idle animation
        let idleAction = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.wait(duration: Double.random(in: 3...8)),
                SCNAction.rotateBy(x: 0, y: CGFloat(Float.random(in: -0.5...0.5)), z: 0, duration: 1),
                SCNAction.wait(duration: Double.random(in: 2...5))
            ])
        )
        personNode.runAction(idleAction)
        
        return personNode
    }
    
    private func applyMaterials() {
        // Add particle system for dust/atmosphere
        let particleSystem = SCNParticleSystem()
        particleSystem.particleLifeSpan = 10
        particleSystem.birthRate = 5
        particleSystem.particleVelocity = 2
        particleSystem.particleVelocityVariation = 5
        particleSystem.particleSize = 0.05
        particleSystem.particleColor = UIColor.white.withAlphaComponent(0.3)
        
        let particleNode = SCNNode()
        particleNode.position = SCNVector3(0, 5, -5)
        particleNode.addParticleSystem(particleSystem)
        scene.rootNode.addChildNode(particleNode)
    }
    
    private func startGameplay() {
        print("🎮 [Real 3D Game] startGameplay() called")
        
        isLoading = false
        
        // Hide loading UI and show game UI
        print("🎮 [Real 3D Game] Starting loading UI hide animation...")
        UIView.animate(withDuration: 1.0, animations: {
            // Hide loading elements
            self.loadingLabel?.alpha = 0
            self.progressView?.alpha = 0
            print("🎮 [Real 3D Game] Loading elements alpha set to 0")
        }) { finished in
            print("🎮 [Real 3D Game] Loading hide animation finished: \(finished)")
            
            // Remove loading UI completely to prevent interaction blocking
            self.loadingContainer?.removeFromSuperview()
            self.loadingLabel = nil
            self.progressView = nil
            self.loadingContainer = nil
            
            print("🎮 [Real 3D Game] Loading UI completely removed from view hierarchy")
            
            // Show game UI elements
            UIView.animate(withDuration: 0.5, animations: {
                self.sceneLabel?.alpha = 1
                self.exitButton?.alpha = 1
                self.interactionButton?.alpha = 1
                print("🎮 [Real 3D Game] Game UI elements shown")
            }) { _ in
                print("🎮 [Real 3D Game] ✅ Game UI animation complete - scene ready for interaction!")
            }
        }
        
        print("🎮 [Real 3D Game] Started REALISTIC Jerusalem gameplay!")
        print("🏠 [Real 3D Game] ✅ Detailed stone walls with towers")
        print("⛪ [Real 3D Game] ✅ Church of the Holy Sepulchre with dome")
        print("👥 [Real 3D Game] ✅ Realistic human characters (Patriarch & Commander)")
        print("🏡 [Real 3D Game] ✅ Traditional Jerusalem houses")
        print("🎥 [Real 3D Game] ✅ Navigation: Pinch to zoom, drag to rotate, pan to move")
    }
    
    private func forceStartGameplay() {
        print("🎮 [Real 3D Game] FORCE starting gameplay - bypassing animations")
        
        isLoading = false
        
        // Immediately remove loading UI
        loadingContainer?.removeFromSuperview()
        loadingLabel?.removeFromSuperview()
        progressView?.removeFromSuperview()
        
        // Immediately show game UI
        sceneLabel?.alpha = 1
        exitButton?.alpha = 1
        interactionButton?.alpha = 1
        
        // Start background music
        audioManager.playAmbientMusic()
        
        // Start first quest
        questManager.startQuest("diplomatic_conquest")
        
        print("🎮 [Real 3D Game] ✅ FORCE startup complete - game should be interactive now!")
        
        // Start background music
        audioManager.playAmbientMusic()
        
        // Start first quest
        questManager.startQuest("diplomatic_conquest")
        
        // Auto transition to Holy Sepulchre after interaction or time
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            if self.gameState.currentQuest?.isCompleted != true {
                self.transitionToHolySepulchre()
            }
        }
    }
    
    private func startCameraAnimation() {
        // Gentle camera sway for immersion
        let cameraSwayAction = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.1, z: 0, duration: 5),
                SCNAction.rotateBy(x: 0, y: -0.2, z: 0, duration: 10),
                SCNAction.rotateBy(x: 0, y: 0.1, z: 0, duration: 5)
            ])
        )
        cameraNode.runAction(cameraSwayAction)
    }
    
    private func transitionToHolySepulchre() {
        currentSceneName = "holy_sepulchre"
        
        UIView.animate(withDuration: 1.5) {
            self.sceneLabel.text = "⛪ Church of the Holy Sepulchre - Sacred Interior"
            self.interactionButton.setTitle("🙏 Make Historic Prayer Decision", for: .normal)
        }
        
        // Change lighting to interior church atmosphere
        lightNode.light?.color = UIColor(red: 0.4, green: 0.3, blue: 0.6, alpha: 1.0)
        lightNode.light?.intensity = 300
        
        // Move characters closer for the prayer scene
        let movePatriarch = SCNAction.move(to: SCNVector3(-1, -2.5, -2), duration: 2.0)
        patriarchNode.runAction(movePatriarch)
    }
    
    // MARK: - User Interaction
    
    @objc private func exitGameTapped() {
        print("🎮 [Real 3D Game] Exit button tapped - closing game")
        
        // Animate exit
        UIView.animate(withDuration: 0.5, animations: {
            self.view.alpha = 0
        }) { _ in
            self.dismiss(animated: false) {
                self.bridge?.quit()
            }
        }
    }
    
    @objc private func interactionTapped() {
        print("🎮 [Real 3D Game] NPC interaction triggered")
        
        // Show advanced dialogue interface
        showDialogueInterface(npcId: "patriarch_sophronius", npcName: "Patriarch Sophronius")
        
        // Animate interaction button
        UIView.animate(withDuration: 0.2, animations: {
            self.interactionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.interactionButton.transform = .identity
            }
        }
    }
    
    private func showDialogueInterface(npcId: String, npcName: String) {
        let dialogueView = DialogueInterface(
            npcId: npcId,
            npcName: npcName,
            gameState: gameState,
            dialogueSystem: dialogueSystem,
            onDismiss: { [weak self] in
                self?.dismissDialogue()
            },
            onChoiceMade: { [weak self] choice in
                self?.handleDialogueChoice(choice)
            }
        )
        
        currentDialogueView = UIHostingController(rootView: dialogueView)
        currentDialogueView?.view.backgroundColor = .clear
        currentDialogueView?.modalPresentationStyle = .overFullScreen
        
        present(currentDialogueView!, animated: true)
        
        // Play dialogue sound
        audioManager.playDialogueSound()
    }
    
    private func dismissDialogue() {
        currentDialogueView?.dismiss(animated: true) {
            self.currentDialogueView = nil
        }
    }
    
    private func handleDialogueChoice(_ choice: DialogueChoice) {
        print("🎮 [Real 3D Game] Player made choice: \(choice.text)")
        
        // Apply choice consequences
        gameState.applyStatChanges(choice.consequences.statChanges)
        
        // Play choice sound
        audioManager.playChoiceSound()
        
        // Check for quest progress
        if let questUpdate = choice.consequences.questUpdate {
            questManager.updateQuest(questUpdate.questId, progress: questUpdate.progress)
            
            // Check if quest completed
            if questUpdate.progress >= 1.0 {
                showQuestCompletionEffect(questUpdate.questId)
            }
        }
        
        // Update scene based on choice
        updateSceneForChoice(choice)
    }
    
    private func updateSceneForChoice(_ choice: DialogueChoice) {
        switch choice.id {
        case "diplomatic_approach":
            // Move closer to patriarch showing trust
            let moveCamera = SCNAction.move(to: SCNVector3(0, 0, 3), duration: 2.0)
            cameraNode.runAction(moveCamera)
            
        case "show_respect":
            // Add golden particle effect showing divine blessing
            addBlessingEffect()
            
        case "religious_unity":
            // Change lighting to heavenly glow
            lightNode.light?.color = UIColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1.0)
            lightNode.light?.intensity = 1200
            
        default:
            break
        }
    }
    
    private func addBlessingEffect() {
        let blessingSystem = SCNParticleSystem()
        blessingSystem.particleLifeSpan = 3
        blessingSystem.birthRate = 20
        blessingSystem.particleVelocity = 1
        blessingSystem.particleSize = 0.1
        blessingSystem.particleColor = UIColor.orange
        
        let blessingNode = SCNNode()
        blessingNode.position = SCNVector3(-3, 0, -5) // Above patriarch
        blessingNode.addParticleSystem(blessingSystem)
        scene.rootNode.addChildNode(blessingNode)
        
        // Remove after effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            blessingNode.removeFromParentNode()
        }
    }
    
    private func showQuestCompletionEffect(_ questId: String) {
        print("🎮 [Real 3D Game] Quest completed: \(questId)")
        
        // Play quest complete sound
        audioManager.playQuestCompleteSound()
        
        // Show celebration particle effect
        let celebrationSystem = SCNParticleSystem()
        celebrationSystem.particleLifeSpan = 2
        celebrationSystem.birthRate = 50
        celebrationSystem.particleVelocity = 3
        celebrationSystem.particleSize = 0.2
        celebrationSystem.particleColor = UIColor.cyan
        
        let celebrationNode = SCNNode()
        celebrationNode.position = SCNVector3(0, 3, -2)
        celebrationNode.addParticleSystem(celebrationSystem)
        scene.rootNode.addChildNode(celebrationNode)
        
        // Flash the scene with golden light
        let originalIntensity = lightNode.light?.intensity ?? 1000
        let flashAction = SCNAction.sequence([
            SCNAction.customAction(duration: 0.5) { _, elapsed in
                let progress = elapsed / 0.5
                self.lightNode.light?.intensity = originalIntensity + (500 * progress)
            },
            SCNAction.customAction(duration: 0.5) { _, elapsed in
                let progress = elapsed / 0.5
                self.lightNode.light?.intensity = (originalIntensity + 500) * (1 - progress) + originalIntensity * progress
            }
        ])
        lightNode.runAction(flashAction)
        
        // Remove celebration effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            celebrationNode.removeFromParentNode()
        }
        
        // Check if this completes the episode
        if questId == "diplomatic_conquest" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.completeEpisode()
            }
        }
    }
    
    private func completeEpisode() {
        print("🎮 [Real 3D Game] Episode completed!")
        
        // Create mission result
        let decisions = gameState.getDecisionHistory()
        let result = MissionResult(
            episodeId: episodeId,
            completed: true,
            score: Double(gameState.playerStats.calculateTotalScore()) / 100.0,
            decisions: decisions.map { decision in
                Decision(
                    id: decision.choiceId,
                    choice: decision.choiceText,
                    timestamp: decision.timestamp.timeIntervalSince1970
                )
            },
            playTime: 120.0 // Mock play time of 2 minutes
        )
        
        // Show completion screen
        let completionAlert = UIAlertController(
            title: "✨ Mission Accomplished!",
            message: "You have successfully negotiated the peaceful surrender of Jerusalem. Score: \(String(format: "%.0f", result.score * 100))%",
            preferredStyle: .alert
        )
        completionAlert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            // Exit game after showing results
            self.exitGameTapped()
        })
        present(completionAlert, animated: true)
        
        // Notify bridge of completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.bridge?.onMissionCompleted?(result)
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: sceneView)
        
        // Convert to camera rotation
        let rotationY = Float(translation.x) * 0.01
        let rotationX = Float(translation.y) * 0.01
        
        cameraNode.eulerAngles.y -= rotationY
        cameraNode.eulerAngles.x -= rotationX
        
        // Clamp vertical rotation
        cameraNode.eulerAngles.x = max(-Float.pi/3, min(Float.pi/3, cameraNode.eulerAngles.x))
        
        gesture.setTranslation(.zero, in: sceneView)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let tapPoint = gesture.location(in: sceneView)
        let hitResults = sceneView.hitTest(tapPoint, options: nil)
        
        if let hit = hitResults.first {
            let hitNode = hit.node
            
            // Check if tapped on character
            if hitNode == patriarchNode {
                showDialogueInterface(npcId: "patriarch_sophronius", npcName: "Patriarch Sophronius")
            } else if hitNode == commanderNode {
                showDialogueInterface(npcId: "commander_khalid", npcName: "Commander Khalid")
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioManager?.stopAllSounds()
    }
    
    deinit {
        audioManager?.stopAllSounds()
    }
}
