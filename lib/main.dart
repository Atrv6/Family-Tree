import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphview/GraphView.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (_) => FamilyTreeProvider(prefs),
      child: const FamilyTreeApp(),
    ),
  );
}

// --- MODEL ---
class Person {
  String name;
  String dob;
  String? notes;
  String? photoPath;

  Person({required this.name, required this.dob, this.notes, this.photoPath});

  Map<String, dynamic> toMap() => {
    'name': name,
    'dob': dob,
    'notes': notes,
    'photoPath': photoPath,
  };

  factory Person.fromMap(Map<String, dynamic> map) => Person(
    name: map['name'],
    dob: map['dob'],
    notes: map['notes'],
    photoPath: map['photoPath'],
  );
}

// --- PROVIDER ---
class PersonNode {
  Person person;
  List<PersonNode> children = [];
  PersonNode({required this.person});

  Map<String, dynamic> toMap() => {
    'person': person.toMap(),
    'children': children.map((c) => c.toMap()).toList(),
  };

  factory PersonNode.fromMap(Map<String, dynamic> map) {
    PersonNode node = PersonNode(person: Person.fromMap(map['person']));
    if (map['children'] != null) {
      node.children = List<PersonNode>.from(
        map['children'].map((c) => PersonNode.fromMap(c)),
      );
    }
    return node;
  }
}

class FamilyTreeProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  List<PersonNode> nodes = [];
  PersonNode? root;

  FamilyTreeProvider(this.prefs) {
    loadData();
  }

  void addPerson({
    required String name,
    required String dob,
    String? notes,
    String? photoPath,
    PersonNode? parent,
  }) {
    final newPerson = Person(
      name: name,
      dob: dob,
      notes: notes,
      photoPath: photoPath,
    );
    final newNode = PersonNode(person: newPerson);

    if (root == null) {
      root = newNode;
    } else {
      parent!.children.add(newNode);
    }

    nodes.add(newNode);
    saveData();
    notifyListeners();
  }

  void deleteNode(PersonNode node) {
    if (root == node) {
      root = null;
      nodes.clear();
    } else {
      PersonNode? parent = _findParent(root!, node);
      if (parent != null) {
        parent.children.remove(node);
        _removeNodesFromList(node);
      }
    }
    saveData();
    notifyListeners();
  }

  PersonNode? _findParent(PersonNode current, PersonNode target) {
    for (var child in current.children) {
      if (child == target) return current;
      var p = _findParent(child, target);
      if (p != null) return p;
    }
    return null;
  }

  void _removeNodesFromList(PersonNode node) {
    nodes.remove(node);
    for (var child in node.children) _removeNodesFromList(child);
  }

  Future<void> saveData() async {
    if (root == null) {
      prefs.remove('family_tree');
      return;
    }
    await prefs.setString('family_tree', jsonEncode(root!.toMap()));
  }

  void loadData() {
    final data = prefs.getString('family_tree');
    if (data != null) {
      try {
        root = PersonNode.fromMap(jsonDecode(data));
        nodes = [];
        _collectNodes(root!);
      } catch (_) {}
    }
    notifyListeners();
  }

  void _collectNodes(PersonNode node) {
    nodes.add(node);
    for (var child in node.children) _collectNodes(child);
  }
}

// --- APP ---
class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Tree',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FamilyHomePage(),
    );
  }
}

// --- HOME PAGE ---
class FamilyHomePage extends StatefulWidget {
  const FamilyHomePage({super.key});

  @override
  _FamilyHomePageState createState() => _FamilyHomePageState();
}

class _FamilyHomePageState extends State<FamilyHomePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? selectedPhotoPath;
  PersonNode? selectedParent;

  bool deleteMode = false; // Delete mode toggle

  final BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration()
    ..siblingSeparation = 30
    ..levelSeparation = 70
    ..subtreeSeparation = 30
    ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

  @override
  Widget build(BuildContext context) {
    final treeProvider = Provider.of<FamilyTreeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Tree')),
      body: Column(
        children: [
          // --- Add/Delete Mode Buttons ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => deleteMode = !deleteMode);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deleteMode ? Colors.red : Colors.grey,
                    ),
                    child: Text(
                      deleteMode ? 'Delete Mode: ON' : 'Delete Mode: OFF',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // --- Input Fields ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: dobController,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'YYYY-MM-DD',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ),
          // --- Photo Picker ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null)
                  setState(() => selectedPhotoPath = image.path);
              },
              child: const Text('Pick Photo (optional)'),
            ),
          ),
          // --- Parent Dropdown ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<PersonNode>(
              hint: const Text('Select Parent'),
              value: selectedParent,
              items: treeProvider.nodes.map((node) {
                return DropdownMenuItem<PersonNode>(
                  value: node,
                  child: Text(node.person.name),
                );
              }).toList(),
              onChanged: (PersonNode? node) =>
                  setState(() => selectedParent = node),
            ),
          ),
          // --- Add Person Button ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty || dobController.text.isEmpty)
                  return;

                if (treeProvider.root != null && selectedParent == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a parent')),
                  );
                  return;
                }

                treeProvider.addPerson(
                  name: nameController.text,
                  dob: dobController.text,
                  notes: notesController.text.isEmpty
                      ? null
                      : notesController.text,
                  photoPath: selectedPhotoPath,
                  parent: selectedParent,
                );

                nameController.clear();
                dobController.clear();
                notesController.clear();
                selectedPhotoPath = null;
                selectedParent = null;
              },
              child: const Text('Add Person'),
            ),
          ),
          const SizedBox(height: 10),
          // --- Tree Display ---
          Expanded(
            child: treeProvider.root != null
                ? Center(
                    child: InteractiveViewer(
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(50),
                      minScale: 0.1,
                      maxScale: 2,
                      child: GraphView(
                        graph: buildGraph(treeProvider.root!),
                        algorithm: BuchheimWalkerAlgorithm(
                          builder,
                          TreeEdgeRenderer(builder),
                        ),
                        builder: (Node node) => node.key!.value,
                      ),
                    ),
                  )
                : const Center(child: Text('No family members yet')),
          ),
        ],
      ),
    );
  }

  Graph buildGraph(PersonNode root) {
    final Graph graph = Graph();
    final Map<PersonNode, Node> nodeMap = {};

    void traverse(PersonNode pNode) {
      Node graphNode = Node(getNodeWidget(pNode));
      nodeMap[pNode] = graphNode;
      graph.addNode(graphNode);

      for (var child in pNode.children) {
        traverse(child);
        graph.addEdge(graphNode, nodeMap[child]!);
      }
    }

    traverse(root);
    return graph;
  }

  Widget getNodeWidget(PersonNode pNode) {
    return Card(
      key: ValueKey(pNode),
      color: Colors.lightBlueAccent,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            if (pNode.person.photoPath != null)
              Image.file(File(pNode.person.photoPath!), width: 50, height: 50),
            Text(pNode.person.name),
            Text(pNode.person.dob),
            if (pNode.person.notes != null) Text(pNode.person.notes!),
            const SizedBox(height: 4),
            if (deleteMode)
              ElevatedButton(
                onPressed: () => confirmDeleteNode(pNode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: const Text('Delete', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  void confirmDeleteNode(PersonNode node) {
    final treeProvider = Provider.of<FamilyTreeProvider>(
      context,
      listen: false,
    );
    bool hasChildren = node.children.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Person'),
        content: Text(
          hasChildren
              ? 'This person has child nodes. Deleting will remove the entire branch. Are you sure?'
              : 'Are you sure you want to delete this person?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              treeProvider.deleteNode(node);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
