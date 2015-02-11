import UIKit
import CoreData

protocol FaghelgApiProtocol {
    func didRecieveResponse(results: NSDictionary)
}

class FaghelgApi : NSObject, NSFetchedResultsControllerDelegate {
    let HOST = "http://faghelg.herokuapp.com";
    
    var data: NSMutableData = NSMutableData()
    var delegate: FaghelgApiProtocol?
    
    var managedObjectContext: NSManagedObjectContext?
    
    var programDAO: ProgramDAO!
    var personDAO: PersonDAO!
    var imageDAO: ImageDAO!

    init(managedObjectContext: NSManagedObjectContext) {
        super.init()
        self.managedObjectContext = managedObjectContext
        self.programDAO = ProgramDAO(managedObjectContext: managedObjectContext)
        self.personDAO = PersonDAO(managedObjectContext: managedObjectContext)
        self.imageDAO = ImageDAO(managedObjectContext: managedObjectContext)
    }
    
    func getProgram(programViewController: ProgramViewController) {
        var url : String = HOST + "/program"
        var request : NSMutableURLRequest = NSMutableURLRequest()
        request.URL = NSURL(string: url)
        request.HTTPMethod = "GET"
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue(), completionHandler:{ (response:NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            var program: Program?
            
            if error != nil {
                program = self.programDAO.getProgram()
                programViewController.showProgram(program)
                return
            }
            
            var error: AutoreleasingUnsafeMutablePointer<NSError?> = nil
            let jsonResult: NSDictionary! = NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions.MutableContainers, error: error) as? NSDictionary
            
            if (jsonResult != nil) {
                program = JsonParser.programFromJson(jsonResult, managedObjectContext: self.managedObjectContext!)
                self.programDAO.saveProgram(program!)
            } else {
                program = self.programDAO.getProgram()
            }
            
            programViewController.showProgram(program)
        })
    }
    
    func getEmployees(employeeViewController: EmployeeViewController) {
        var url : String = HOST + "/persons"
        var request : NSMutableURLRequest = NSMutableURLRequest()
        request.URL = NSURL(string: url)
        request.HTTPMethod = "GET"
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue(), completionHandler:{ (response:NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            var employees: [Person]?
            
            if error != nil {
                employees = self.personDAO.getPersons()
                employeeViewController.showEmployees(employees)
                return
            }
            
            var error: AutoreleasingUnsafeMutablePointer<NSError?> = nil
            let jsonResult: NSArray! = NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions.MutableContainers, error: error) as? NSArray
            
            if (jsonResult != nil) {
                employees = [Person]()
                for jsonObject in jsonResult {
                    var jsonDict = jsonObject as NSDictionary
                    let employee = JsonParser.personFromJson(jsonDict, managedObjectContext: self.managedObjectContext!)
                    employees!.append(employee)
                    self.personDAO.savePerson(employee)
                    self.managedObjectContext?.save(nil);
                }
            } else {
                employees = self.personDAO.getPersons()
            }
            
            var sortedEmployees = sorted(employees!){ $0.fullName < $1.fullName }
            employeeViewController.showEmployees(sortedEmployees)
        })
    }
    
    func getImage(imageUrl: String) -> UIImage? {
        var managedObjectContext = (UIApplication.sharedApplication().delegate as AppDelegate).managedObjectContext
        
        let shortName = imageUrl.componentsSeparatedByString("/").last!
        
        if let imageFromDatabase = imageDAO.getImage(shortName) {
            return UIImage(data: imageFromDatabase.imageData)
        }
        
        if let newBilde = downloadImageFromWeb(imageUrl, shortName: shortName, managedObjectContext: managedObjectContext!) {
            newBilde.save()
            return UIImage(data: newBilde.imageData)!
        }
        
        return nil
    }
    
    func downloadImageFromWeb(imageUrl: String, shortName: String, managedObjectContext: NSManagedObjectContext) -> Bilde? {
        let url = NSURL(string:imageUrl);
        var err: NSError? = nil
        
        if let imageData = NSData(contentsOfURL: url!,options: NSDataReadingOptions.DataReadingMappedIfSafe, error: &err) {
            
            var bilde: Bilde = Bilde(entity: NSEntityDescription.entityForName("Bilde", inManagedObjectContext: managedObjectContext)!, insertIntoManagedObjectContext: managedObjectContext)
            
            bilde.shortName = shortName
            bilde.imageData = imageData
            return bilde
        }
        
        return nil
    }
}
