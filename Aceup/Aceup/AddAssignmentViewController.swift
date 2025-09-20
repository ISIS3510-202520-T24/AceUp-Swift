import UIKit



final class AddAssignmentViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Assignment"
    }

    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        // TODO: validar y guardar
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @IBAction func doneTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        let name = sender.isSelected ? "checkmark.square.fill" : "square"
        sender.setImage(UIImage(systemName: name), for: .normal)
        sender.tintColor = sender.isSelected ? .systemTeal : .secondaryLabel
    }

    @IBAction func dueDateTapped(_ sender: UIButton) {
        let ac = UIAlertController(title: "Select due date", message: nil, preferredStyle: .actionSheet)

        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .wheels
        picker.minimumDate = Date()

        ac.view.addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: ac.view.leadingAnchor, constant: 8),
            picker.trailingAnchor.constraint(equalTo: ac.view.trailingAnchor, constant: -8),
            picker.topAnchor.constraint(equalTo: ac.view.topAnchor, constant: 8),
            picker.heightAnchor.constraint(equalToConstant: 216)
        ])

        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
            sender.setTitle(f.string(from: picker.date), for: .normal)
        }))

        present(ac, animated: true)
    }
}

