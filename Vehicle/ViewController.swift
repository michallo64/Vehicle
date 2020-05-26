//
//  ViewController.swift
//  Vehicle
//
//  Created by Michal Podroužek on 09/04/2020.
//  Copyright © 2020 Michal Podroužek. All rights reserved.
//

import UIKit
import ARKit
import CoreMotion

class ViewController: UIViewController, ARSCNViewDelegate {
    
    let configuration = ARWorldTrackingConfiguration()
    @IBOutlet weak var sceneView: ARSCNView!
    let motionManager = CMMotionManager()
    var vehicle = SCNPhysicsVehicle()
    var orientation:CGFloat = 0
    var touched:Int = 0
    var accelerationValues = [UIAccelerationValue(0), UIAccelerationValue(0)]
    var time:Int = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.sceneView.debugOptions = [SCNDebugOptions.showWorldOrigin, SCNDebugOptions.showFeaturePoints]
        self.configuration.planeDetection = .horizontal
        self.sceneView.session.run(configuration)
        self.sceneView.delegate = self
        self.setUpAccelerometer()
        self.sceneView.showsStatistics = true
        // Do any additional setup after loading the view.
    }
    
    func createConcrete(planeAnchor:ARPlaneAnchor)->SCNNode{
        let concreteNode = SCNNode(geometry: SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z)))
        concreteNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "concrete")
        concreteNode.position = SCNVector3(planeAnchor.center.x,planeAnchor.center.y,planeAnchor.center.z)
        concreteNode.geometry?.firstMaterial?.isDoubleSided = true
        concreteNode.eulerAngles = SCNVector3(90.degreesToRadians, 0, 0)
        let staticBody = SCNPhysicsBody.static()
        concreteNode.physicsBody = staticBody
        return concreteNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else{return}
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else{return}
        node.enumerateChildNodes{(childNode, _) in
            childNode.removeFromParentNode()
        }
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
    }
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else{return}
        node.enumerateChildNodes{(childNode, _) in
            childNode.removeFromParentNode()
        }
    }
    
    @IBAction func addCar(_ sender: Any) {
        guard let pointsOfView = sceneView.pointOfView else{return}
        let transform = pointsOfView.transform
        let orientation = SCNVector3(-transform.m31,-transform.m32,-transform.m33)
        let location = SCNVector3(transform.m41,transform.m42,transform.m43)
        let currentPositionOfCamera = orientation + location
        let scene = SCNScene(named: "car.scn")
        let chassis = (scene?.rootNode.childNode(withName: "chassis", recursively: false))!
        
        let leftFrontWheel = chassis.childNode(withName: "frontLeftParent", recursively: false)
        let rightFrontWheel = chassis.childNode(withName: "frontRightParent", recursively: false)
        let leftRearWheel = chassis.childNode(withName: "rearLeftParent", recursively: false)
        let rightRearWheel = chassis.childNode(withName: "rearRightParent", recursively: false)
        let v_frontLeftWheel = SCNPhysicsVehicleWheel(node: leftFrontWheel!)
        let v_frontRightWheel = SCNPhysicsVehicleWheel(node: rightFrontWheel!)
        let v_rearLeftWheel = SCNPhysicsVehicleWheel(node: leftRearWheel!)
        let v_rearRightWheel = SCNPhysicsVehicleWheel(node: rightRearWheel!)

        chassis.position = currentPositionOfCamera
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: chassis, options: [SCNPhysicsShape.Option.keepAsCompound:true]))
        body.mass = 5
        chassis.physicsBody = body
        self.vehicle = SCNPhysicsVehicle(chassisBody: chassis.physicsBody!, wheels: [v_rearLeftWheel, v_rearRightWheel, v_frontLeftWheel, v_frontRightWheel])
        self.sceneView.scene.physicsWorld.addBehavior(self.vehicle)
        self.sceneView.scene.rootNode.childNodes.filter({$0.name == "chassis"}).forEach({$0.removeFromParentNode()})
        self.sceneView.scene.rootNode.addChildNode(chassis)
    }
    
    func sendData() {
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
//        print("simulating physics")
        var engineForces:CGFloat = 0
        var brakingForce:CGFloat = 0
        self.vehicle.setSteeringAngle(orientation, forWheelAt: 2)
        self.vehicle.setSteeringAngle(orientation, forWheelAt: 3)
        if(self.touched == 1){
            engineForces = 20
        }else if(self.touched == 2){
            engineForces = -20
        } else if(self.touched == 3){
            brakingForce = 100
        }
        else{
            engineForces = 0
        }
        self.vehicle.applyEngineForce(engineForces, forWheelAt: 0)
        self.vehicle.applyEngineForce(engineForces, forWheelAt: 1)
        self.vehicle.applyBrakingForce(brakingForce, forWheelAt: 0)
        self.vehicle.applyBrakingForce(brakingForce, forWheelAt: 1)
        self.time+=1;
        if(self.time == 60){
            self.time = 0;
//            print("x:" + String(accelerationValues[0]) + " y:" + String(accelerationValues[1]));
        }
        
    }
    
    func setUpAccelerometer(){
        if(motionManager.isAccelerometerAvailable){
            motionManager.accelerometerUpdateInterval = 1/60
            motionManager.startAccelerometerUpdates(to: .main, withHandler:
                {(accelerometerData, error) in
                    if let error = error{
                        print(error.localizedDescription)
                        return
                    }
                    self.accelerometerDidChange(acceleration: accelerometerData!.acceleration)
            })
        }else{
            print("accelometer not available")
        }
    }

    func accelerometerDidChange(acceleration:CMAcceleration){
        accelerationValues[1] = filtered(previousAcceleration: accelerationValues[1], UpdatedAcceleration: acceleration.y)
        accelerationValues[0] = filtered(previousAcceleration: accelerationValues[0], UpdatedAcceleration: acceleration.x)
        if(accelerationValues[0]>0){
            self.orientation = CGFloat(accelerationValues[1])
        }else{
            self.orientation = -CGFloat(accelerationValues[1])
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = touches.first else{return}
        self.touched += touches.count
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touched = 0
    }
    func filtered(previousAcceleration: Double, UpdatedAcceleration: Double) -> Double {
        let kfilteringFactor = 0.5
        return UpdatedAcceleration * kfilteringFactor + previousAcceleration * (1-kfilteringFactor)
    }
    
    @IBAction func sendData(_ sender: UIButton) {
        let url = URL(string: "http://192.168.1.234:8888/poit/index.php")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "test"),
            URLQueryItem(name: "key2", value: "1")
        ]
        let query = components.url!.query
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(query!.utf8)
        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            do {
                //create json object from data
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    print(json)
                    // handle json...
                }
            } catch let error {
                print(error.localizedDescription)
            }
        })
        task.resume()
    }
    
    
    
    
}

extension Int{
    var degreesToRadians:Double{ return Double(self) * .pi/180}
}

func +(left:SCNVector3, right:SCNVector3)->SCNVector3{
    return SCNVector3Make(left.x+right.x, left.y+right.y, left.z+right.z)
}
