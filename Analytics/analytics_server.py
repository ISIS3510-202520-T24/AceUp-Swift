#!/usr/bin/env python3
"""
AceUp Analytics Server
Local analytics server for Business Question analysis
Port: 8080

BQ 2.1: For a student, what is the next assignment or exam in their calendar 
that carries the highest weight toward their final grade and is still marked as "Pending"?
"""

import json
import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
import webbrowser
import time

class AnalyticsData:
    """Mock academic data for analytics demonstration"""
    
    @staticmethod
    def get_student_data(user_id="student123"):
        """Generate realistic student academic data"""
        now = datetime.datetime.now()
        
        # Sample courses
        courses = [
            {
                "id": "cs101",
                "name": "Introduction to Computer Science", 
                "code": "CS 101",
                "credits": 3,
                "instructor": "Dr. Smith",
                "color": "#122C4A",
                "semester": "Fall",
                "year": 2024,
                "grade_weight": {
                    "assignments": 0.4,
                    "exams": 0.4, 
                    "projects": 0.15,
                    "participation": 0.05
                },
                "current_grade": 0.85,
                "target_grade": 0.90
            },
            {
                "id": "math201",
                "name": "Calculus II",
                "code": "MATH 201", 
                "credits": 4,
                "instructor": "Prof. Johnson",
                "color": "#50E3C2",
                "semester": "Fall",
                "year": 2024,
                "grade_weight": {
                    "assignments": 0.25,
                    "exams": 0.60,
                    "projects": 0.0,
                    "participation": 0.15
                },
                "current_grade": 0.78,
                "target_grade": 0.85
            },
            {
                "id": "phys151",
                "name": "Physics I",
                "code": "PHYS 151",
                "credits": 4,
                "instructor": "Dr. Wilson",
                "color": "#FF6B6B",
                "semester": "Fall", 
                "year": 2024,
                "grade_weight": {
                    "assignments": 0.20,
                    "exams": 0.50,
                    "projects": 0.20,
                    "participation": 0.10
                },
                "current_grade": 0.82,
                "target_grade": 0.88
            }
        ]
        
        # Sample academic events
        events = [
            {
                "id": "event1",
                "title": "Final Programming Project",
                "description": "Develop a complete web application using React and Node.js",
                "course_id": "cs101",
                "course_name": "Introduction to Computer Science",
                "type": "project",
                "due_date": (now + datetime.timedelta(days=5)).isoformat(),
                "weight": 0.25,
                "status": "pending",
                "priority": "high",
                "estimated_hours": 20
            },
            {
                "id": "event2", 
                "title": "Calculus Midterm Exam",
                "description": "Comprehensive exam covering integration techniques and applications",
                "course_id": "math201",
                "course_name": "Calculus II",
                "type": "exam",
                "due_date": (now + datetime.timedelta(days=2)).isoformat(),
                "weight": 0.30,
                "status": "pending", 
                "priority": "critical",
                "estimated_hours": 8
            },
            {
                "id": "event3",
                "title": "Physics Lab Report #3",
                "description": "Analysis of pendulum motion and harmonic oscillation",
                "course_id": "phys151",
                "course_name": "Physics I",
                "type": "assignment",
                "due_date": (now + datetime.timedelta(days=1)).isoformat(),
                "weight": 0.08,
                "status": "pending",
                "priority": "medium",
                "estimated_hours": 4
            },
            {
                "id": "event4",
                "title": "Homework Assignment 7",
                "description": "Integration by parts and partial fractions",
                "course_id": "math201", 
                "course_name": "Calculus II",
                "type": "homework",
                "due_date": (now + datetime.timedelta(days=7)).isoformat(),
                "weight": 0.05,
                "status": "pending",
                "priority": "medium", 
                "estimated_hours": 3
            },
            {
                "id": "event5",
                "title": "Algorithm Analysis Quiz",
                "description": "Big O notation and complexity analysis",
                "course_id": "cs101",
                "course_name": "Introduction to Computer Science", 
                "type": "quiz",
                "due_date": (now + datetime.timedelta(days=10)).isoformat(),
                "weight": 0.08,
                "status": "pending",
                "priority": "medium",
                "estimated_hours": 2
            },
            {
                "id": "event6",
                "title": "Physics Final Exam",
                "description": "Comprehensive final covering all semester material",
                "course_id": "phys151",
                "course_name": "Physics I",
                "type": "exam", 
                "due_date": (now + datetime.timedelta(days=12)).isoformat(),
                "weight": 0.35,
                "status": "pending",
                "priority": "high",
                "estimated_hours": 12
            }
        ]
        
        return {
            "user_id": user_id,
            "courses": courses,
            "events": events,
            "last_updated": now.isoformat()
        }

class AnalyticsEngine:
    """Business logic for academic analytics"""
    
    @staticmethod
    def calculate_priority_score(event, current_time):
        """Calculate priority score based on weight, urgency, and type"""
        due_date = datetime.datetime.fromisoformat(event["due_date"].replace('Z', '+00:00'))
        days_until_due = (due_date - current_time).days
        
        # Weight factor (0-100)
        weight_factor = event["weight"] * 100
        
        # Urgency factor (more urgent = higher score)
        urgency_factor = max(0, 14 - days_until_due) * 5
        
        # Type factor
        type_multipliers = {
            "exam": 1.2,
            "project": 1.1, 
            "assignment": 1.0,
            "quiz": 0.9,
            "homework": 0.8
        }
        type_factor = type_multipliers.get(event["type"], 1.0)
        
        # Status penalty
        status_penalty = 0 if event["status"] == "pending" else -50
        
        priority_score = (weight_factor + urgency_factor) * type_factor + status_penalty
        return round(priority_score, 2)
    
    @staticmethod
    def get_urgency_level(days_until_due):
        """Determine urgency level based on days until due"""
        if days_until_due <= 1:
            return "critical"
        elif days_until_due <= 3:
            return "high"
        elif days_until_due <= 7:
            return "moderate"
        else:
            return "low"
    
    @staticmethod
    def generate_recommendations(event, total_pending, days_until_due):
        """Generate personalized recommendations"""
        recommendations = []
        
        # Time-based recommendations
        if days_until_due <= 1:
            recommendations.append("🚨 URGENT: This {} is due within 24 hours!".format(event["type"]))
            recommendations.append("Focus solely on this task and complete it as soon as possible")
        elif days_until_due <= 3:
            recommendations.append("⚠️ Priority: This {} is due very soon".format(event["type"]))
            recommendations.append("Allocate significant time today to work on this")
        elif days_until_due <= 7:
            recommendations.append("📅 Plan ahead: Start working on this {} soon".format(event["type"]))
        
        # Weight-based recommendations  
        weight_percentage = int(event["weight"] * 100)
        if event["weight"] >= 0.3:
            recommendations.append("💎 High Impact: This task represents {}% of your grade".format(weight_percentage))
            recommendations.append("Consider dedicating extra study time given its importance")
        elif event["weight"] >= 0.15:
            recommendations.append("📊 Moderate Impact: Worth {}% of your final grade".format(weight_percentage))
        
        # Workload recommendations
        if total_pending >= 8:
            recommendations.append("📚 Heavy workload detected - prioritize by due date and weight")
            recommendations.append("Break down large tasks into smaller, manageable chunks")
        
        # Type-specific recommendations
        if event["type"] == "exam":
            recommendations.append("📖 Create a study schedule leading up to the exam")
            recommendations.append("Review past materials and practice problems")
        elif event["type"] == "project":
            recommendations.append("🛠️ Break this project into phases with mini-deadlines")
            recommendations.append("Start with research and planning phases")
        elif event["type"] == "assignment":
            recommendations.append("✍️ Begin with an outline or initial draft")
        
        return recommendations
    
    @staticmethod
    def analyze_highest_weight_event(user_id):
        """
        BQ 2.1: Find the highest weight pending academic event
        """
        student_data = AnalyticsData.get_student_data(user_id)
        current_time = datetime.datetime.now()
        
        # Filter pending events
        pending_events = [e for e in student_data["events"] if e["status"] == "pending"]
        
        if not pending_events:
            return {
                "success": True,
                "message": "No pending academic events found. Great job staying on top of your work!",
                "data": {
                    "event": None,
                    "analysis": {
                        "total_pending_events": 0,
                        "average_weight": 0.0,
                        "days_to_due": 0,
                        "urgency_level": "low",
                        "impact_score": 0.0,
                        "course_load": "Light"
                    },
                    "recommendations": [
                        "Consider planning ahead for upcoming assignments",
                        "Review your course syllabi for future deadlines", 
                        "Use this free time to get ahead on reading or projects"
                    ]
                },
                "timestamp": current_time.isoformat(),
                "user_id": user_id
            }
        
        # Calculate priority scores for all pending events
        for event in pending_events:
            event["priority_score"] = AnalyticsEngine.calculate_priority_score(event, current_time)
            due_date = datetime.datetime.fromisoformat(event["due_date"].replace('Z', '+00:00'))
            event["days_until_due"] = (due_date - current_time).days
        
        # Find highest priority event
        highest_priority_event = max(pending_events, key=lambda e: e["priority_score"])
        
        # Calculate analysis metrics
        total_weight = sum(e["weight"] for e in pending_events)
        average_weight = total_weight / len(pending_events)
        
        urgency_level = AnalyticsEngine.get_urgency_level(highest_priority_event["days_until_due"])
        
        # Determine course load
        if len(pending_events) >= 8:
            course_load = "Heavy"
        elif len(pending_events) >= 5:
            course_load = "Moderate"
        else:
            course_load = "Light"
        
        # Generate recommendations
        recommendations = AnalyticsEngine.generate_recommendations(
            highest_priority_event, 
            len(pending_events),
            highest_priority_event["days_until_due"]
        )
        
        return {
            "success": True,
            "message": "Successfully identified highest priority pending academic event",
            "data": {
                "event": highest_priority_event,
                "analysis": {
                    "total_pending_events": len(pending_events),
                    "average_weight": round(average_weight, 3),
                    "days_to_due": highest_priority_event["days_until_due"],
                    "urgency_level": urgency_level,
                    "impact_score": highest_priority_event["priority_score"],
                    "course_load": course_load
                },
                "recommendations": recommendations
            },
            "timestamp": current_time.isoformat(),
            "user_id": user_id
        }

class AnalyticsHandler(BaseHTTPRequestHandler):
    """HTTP request handler for analytics API"""
    
    def _set_cors_headers(self):
        """Set CORS headers for cross-origin requests"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    
    def _send_json_response(self, data, status_code=200):
        """Send JSON response with proper headers"""
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self._set_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self._set_cors_headers()
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        query_params = parse_qs(parsed_url.query)
        
        if path == '/':
            # Serve analytics dashboard
            self._serve_dashboard()
        elif path == '/api/health':
            # Health check endpoint
            self._send_json_response({
                "status": "healthy",
                "service": "AceUp Analytics Server",
                "timestamp": datetime.datetime.now().isoformat(),
                "version": "1.0.0"
            })
        elif path == '/api/highest-weight-event':
            # BQ 2.1 endpoint
            user_id = query_params.get('user_id', ['student123'])[0]
            result = AnalyticsEngine.analyze_highest_weight_event(user_id)
            self._send_json_response(result)
        elif path == '/api/student-data':
            # Raw student data endpoint
            user_id = query_params.get('user_id', ['student123'])[0]
            data = AnalyticsData.get_student_data(user_id)
            self._send_json_response(data)
        else:
            # 404 for unknown endpoints
            self._send_json_response({
                "error": "Endpoint not found",
                "available_endpoints": [
                    "/api/health",
                    "/api/highest-weight-event",
                    "/api/student-data"
                ]
            }, 404)
    
    def _serve_dashboard(self):
        """Serve analytics dashboard HTML with interactive charts"""
        html_content = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AceUp Analytics Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #50E3C2 0%, #122C4A 100%);
            min-height: 100vh;
            color: #333;
        }
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 40px 20px;
            background: rgba(255,255,255,0.95);
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header h1 {
            font-size: 3rem;
            color: #122C4A;
            margin-bottom: 10px;
            font-weight: 700;
        }
        .header h2 {
            font-size: 1.5rem;
            color: #50E3C2;
            margin-bottom: 20px;
            font-weight: 500;
        }
        .bq-title {
            background: linear-gradient(45deg, #50E3C2, #122C4A);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-size: 1.2rem;
            font-weight: 600;
            margin-bottom: 20px;
        }
        .description {
            font-size: 1.1rem;
            color: #666;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
        }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }
        .card {
            background: white;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 12px 36px rgba(0,0,0,0.15);
        }
        .card h3 {
            color: #122C4A;
            font-size: 1.4rem;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .icon {
            font-size: 1.5rem;
        }
        .card p {
            color: #666;
            line-height: 1.6;
            margin-bottom: 20px;
        }
        .btn {
            background: linear-gradient(45deg, #50E3C2, #122C4A);
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 1rem;
            font-weight: 600;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(80, 227, 194, 0.4);
        }
        .chart-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
            margin: 40px 0;
        }
        .chart-card {
            background: white;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
        }
        .chart-card h3 {
            color: #122C4A;
            margin-bottom: 20px;
            font-size: 1.3rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .chart-container {
            position: relative;
            height: 300px;
            margin-bottom: 20px;
        }
        .chart-container canvas {
            max-height: 300px !important;
        }
        .results {
            background: white;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
            margin-top: 30px;
        }
        .results h3 {
            color: #122C4A;
            margin-bottom: 20px;
            font-size: 1.4rem;
        }
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
            font-style: italic;
        }
        pre {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            overflow-x: auto;
            font-size: 0.9rem;
            line-height: 1.4;
            border-left: 4px solid #50E3C2;
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 12px;
            border-left: 4px solid #50E3C2;
        }
        .metric-value {
            font-size: 2rem;
            font-weight: bold;
            color: #122C4A;
        }
        .metric-label {
            color: #666;
            font-size: 0.9rem;
            margin-top: 5px;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: rgba(255,255,255,0.8);
        }
        .priority-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: bold;
            color: white;
            margin: 2px;
        }
        .critical { background: #FF4757; }
        .high { background: #FF6B6B; }
        .moderate { background: #FFE66D; color: #333; }
        .low { background: #4ECDC4; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 AceUp Analytics Dashboard</h1>
            <h2>Academic Priority Intelligence with Visual Analytics</h2>
            <div class="bq-title">Business Question 2.1 - Interactive Charts</div>
            <div class="description">
                This analytics system answers the question: <strong>"For a student, what is the next assignment or exam in their calendar that carries the highest weight toward their final grade and is still marked as 'Pending'?"</strong>
                <br><br>
                Enhanced with interactive visualizations for better insights and decision-making.
            </div>
        </div>
        
        <div class="dashboard">
            <div class="card">
                <h3><span class="icon">🎯</span>Priority Analysis</h3>
                <p>Discover your highest-impact pending academic event with visual priority scoring.</p>
                <button class="btn" onclick="analyzeEvents()">Analyze My Workload</button>
            </div>
            
            <div class="card">
                <h3><span class="icon">📈</span>Performance Charts</h3>
                <p>Interactive charts showing grade trends, workload distribution, and progress over time.</p>
                <button class="btn" onclick="loadCharts()">View Analytics Charts</button>
            </div>
            
            <div class="card">
                <h3><span class="icon">📊</span>Academic Data</h3>
                <p>View your current courses, assignments, and academic schedule data.</p>
                <button class="btn" onclick="loadStudentData()">View My Data</button>
            </div>
            
            <div class="card">
                <h3><span class="icon">🔍</span>API Explorer</h3>
                <p>Test the analytics API endpoints directly and see raw JSON responses.</p>
                <a href="/api/highest-weight-event" target="_blank" class="btn">View API Response</a>
            </div>
        </div>
        
        <div id="charts-section" style="display: none;">
            <div class="chart-grid">
                <div class="chart-card">
                    <h3>📊 Workload Distribution</h3>
                    <div class="chart-container">
                        <canvas id="workloadChart"></canvas>
                    </div>
                </div>
                
                <div class="chart-card">
                    <h3>🎯 Priority Breakdown</h3>
                    <div class="chart-container">
                        <canvas id="priorityChart"></canvas>
                    </div>
                </div>
                
                <div class="chart-card">
                    <h3>📈 Grade Performance</h3>
                    <div class="chart-container">
                        <canvas id="gradeChart"></canvas>
                    </div>
                </div>
                
                <div class="chart-card">
                    <h3>⏰ Upcoming Deadlines</h3>
                    <div class="chart-container">
                        <canvas id="deadlineChart"></canvas>
                    </div>
                </div>
                
                <div class="chart-card">
                    <h3>📅 Weekly Progress</h3>
                    <div class="chart-container">
                        <canvas id="progressChart"></canvas>
                    </div>
                </div>
                
                <div class="chart-card">
                    <h3>💎 Event Weight Analysis</h3>
                    <div class="chart-container">
                        <canvas id="weightChart"></canvas>
                    </div>
                </div>
            </div>
        </div>
        
        <div id="results" class="results" style="display: none;">
            <h3>Analysis Results</h3>
            <div id="results-content"></div>
        </div>
        
        <div class="footer">
            <p>AceUp Analytics Server • Running on localhost:8080 • Real-time Academic Intelligence with Interactive Charts</p>
        </div>
    </div>

    <script>
        let studentData = null;
        let charts = {};

        async function loadCharts() {
            try {
                // Load student data first
                const response = await fetch('/api/student-data?user_id=student123');
                studentData = await response.json();
                
                document.getElementById('charts-section').style.display = 'block';
                document.getElementById('charts-section').scrollIntoView({ behavior: 'smooth' });
                
                // Create all charts
                createWorkloadChart();
                createPriorityChart();
                createGradeChart();
                createDeadlineChart();
                createProgressChart();
                createWeightChart();
                
            } catch (error) {
                console.error('Error loading charts:', error);
            }
        }

        function createWorkloadChart() {
            const ctx = document.getElementById('workloadChart').getContext('2d');
            
            const statusCounts = getStatusCounts(studentData.events);
            
            charts.workload = new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: statusCounts.map(s => s.status),
                    datasets: [{
                        data: statusCounts.map(s => s.count),
                        backgroundColor: statusCounts.map(s => s.color),
                        borderWidth: 2,
                        borderColor: '#fff'
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'bottom'
                        },
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                    const percentage = ((context.parsed / total) * 100).toFixed(1);
                                    return `${context.label}: ${context.parsed} (${percentage}%)`;
                                }
                            }
                        }
                    }
                }
            });
        }

        function createPriorityChart() {
            const ctx = document.getElementById('priorityChart').getContext('2d');
            
            const priorityCounts = getPriorityCounts(studentData.events);
            
            charts.priority = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: priorityCounts.map(p => p.priority),
                    datasets: [{
                        label: 'Number of Tasks',
                        data: priorityCounts.map(p => p.count),
                        backgroundColor: priorityCounts.map(p => p.color + '80'),
                        borderColor: priorityCounts.map(p => p.color),
                        borderWidth: 2,
                        borderRadius: 8
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true,
                            ticks: {
                                stepSize: 1
                            }
                        }
                    },
                    plugins: {
                        legend: {
                            display: false
                        }
                    }
                }
            });
        }

        function createGradeChart() {
            const ctx = document.getElementById('gradeChart').getContext('2d');
            
            charts.grade = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: studentData.courses.map(c => c.code),
                    datasets: [{
                        label: 'Current Grade',
                        data: studentData.courses.map(c => (c.current_grade || 0) * 100),
                        backgroundColor: '#50E3C280',
                        borderColor: '#50E3C2',
                        borderWidth: 2,
                        borderRadius: 6
                    }, {
                        label: 'Target Grade',
                        data: studentData.courses.map(c => (c.target_grade || 0) * 100),
                        backgroundColor: '#FF6B6B80',
                        borderColor: '#FF6B6B',
                        borderWidth: 2,
                        borderRadius: 6
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true,
                            max: 100,
                            ticks: {
                                callback: function(value) {
                                    return value + '%';
                                }
                            }
                        }
                    }
                }
            });
        }

        function createDeadlineChart() {
            const ctx = document.getElementById('deadlineChart').getContext('2d');
            
            const upcomingEvents = getUpcomingEvents(studentData.events, 14);
            
            charts.deadline = new Chart(ctx, {
                type: 'scatter',
                data: {
                    datasets: [{
                        label: 'Assignments',
                        data: upcomingEvents.filter(e => e.type === 'assignment').map(e => ({
                            x: getDaysUntilDue(e.due_date),
                            y: e.weight * 100
                        })),
                        backgroundColor: '#5352ED',
                        borderColor: '#5352ED',
                        pointRadius: 8
                    }, {
                        label: 'Exams',
                        data: upcomingEvents.filter(e => e.type === 'exam').map(e => ({
                            x: getDaysUntilDue(e.due_date),
                            y: e.weight * 100
                        })),
                        backgroundColor: '#FF4757',
                        borderColor: '#FF4757',
                        pointRadius: 10
                    }, {
                        label: 'Projects',
                        data: upcomingEvents.filter(e => e.type === 'project').map(e => ({
                            x: getDaysUntilDue(e.due_date),
                            y: e.weight * 100
                        })),
                        backgroundColor: '#50E3C2',
                        borderColor: '#50E3C2',
                        pointRadius: 12
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        x: {
                            title: {
                                display: true,
                                text: 'Days Until Due'
                            },
                            min: 0,
                            max: 14
                        },
                        y: {
                            title: {
                                display: true,
                                text: 'Grade Weight (%)'
                            },
                            min: 0,
                            max: 40
                        }
                    }
                }
            });
        }

        function createProgressChart() {
            const ctx = document.getElementById('progressChart').getContext('2d');
            
            const weeklyData = getWeeklyProgress();
            
            charts.progress = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: weeklyData.map(w => w.week),
                    datasets: [{
                        label: 'Completed Tasks',
                        data: weeklyData.map(w => w.completed),
                        borderColor: '#4ECDC4',
                        backgroundColor: '#4ECDC480',
                        fill: true,
                        tension: 0.4,
                        pointRadius: 6,
                        pointHoverRadius: 8
                    }, {
                        label: 'Pending Tasks',
                        data: weeklyData.map(w => w.pending),
                        borderColor: '#FF6B6B',
                        backgroundColor: '#FF6B6B80',
                        fill: true,
                        tension: 0.4,
                        pointRadius: 6,
                        pointHoverRadius: 8
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true,
                            ticks: {
                                stepSize: 2
                            }
                        }
                    },
                    interaction: {
                        intersect: false,
                        mode: 'index'
                    }
                }
            });
        }

        function createWeightChart() {
            const ctx = document.getElementById('weightChart').getContext('2d');
            
            const weightDistribution = getWeightDistribution(studentData.events);
            
            charts.weight = new Chart(ctx, {
                type: 'polarArea',
                data: {
                    labels: weightDistribution.map(w => w.range),
                    datasets: [{
                        data: weightDistribution.map(w => w.count),
                        backgroundColor: [
                            '#4ECDC480',
                            '#50E3C280',
                            '#FFE66D80',
                            '#FF6B6B80',
                            '#FF475780'
                        ],
                        borderColor: [
                            '#4ECDC4',
                            '#50E3C2',
                            '#FFE66D',
                            '#FF6B6B',
                            '#FF4757'
                        ],
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'bottom'
                        }
                    }
                }
            });
        }

        // Helper functions
        function getStatusCounts(events) {
            const statusMap = {
                'pending': { color: '#FFE66D', count: 0 },
                'in_progress': { color: '#5352ED', count: 0 },
                'completed': { color: '#4ECDC4', count: 0 },
                'overdue': { color: '#FF6B6B', count: 0 }
            };
            
            events.forEach(event => {
                if (statusMap[event.status]) {
                    statusMap[event.status].count++;
                }
            });
            
            return Object.entries(statusMap)
                .map(([status, data]) => ({ status: status.replace('_', ' '), ...data }))
                .filter(item => item.count > 0);
        }

        function getPriorityCounts(events) {
            const priorityMap = {
                'low': { color: '#4ECDC4', count: 0 },
                'medium': { color: '#FFE66D', count: 0 },
                'high': { color: '#FF6B6B', count: 0 },
                'critical': { color: '#FF4757', count: 0 }
            };
            
            events.forEach(event => {
                if (priorityMap[event.priority]) {
                    priorityMap[event.priority].count++;
                }
            });
            
            return Object.entries(priorityMap)
                .map(([priority, data]) => ({ priority, ...data }))
                .filter(item => item.count > 0);
        }

        function getUpcomingEvents(events, days) {
            const now = new Date();
            return events.filter(event => {
                const dueDate = new Date(event.due_date);
                const daysDiff = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24));
                return event.status === 'pending' && daysDiff >= 0 && daysDiff <= days;
            });
        }

        function getDaysUntilDue(dueDateStr) {
            const now = new Date();
            const dueDate = new Date(dueDateStr);
            return Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24));
        }

        function getWeeklyProgress() {
            return [
                { week: 'Week 1', completed: 8, pending: 4 },
                { week: 'Week 2', completed: 6, pending: 6 },
                { week: 'Week 3', completed: 10, pending: 3 },
                { week: 'Week 4', completed: 7, pending: 5 },
                { week: 'Current', completed: 9, pending: 6 }
            ];
        }

        function getWeightDistribution(events) {
            const ranges = [
                { range: '0-5%', min: 0, max: 0.05, count: 0 },
                { range: '5-15%', min: 0.05, max: 0.15, count: 0 },
                { range: '15-25%', min: 0.15, max: 0.25, count: 0 },
                { range: '25-35%', min: 0.25, max: 0.35, count: 0 },
                { range: '35%+', min: 0.35, max: 1, count: 0 }
            ];
            
            events.forEach(event => {
                ranges.forEach(range => {
                    if (event.weight >= range.min && event.weight < range.max) {
                        range.count++;
                    }
                });
            });
            
            return ranges.filter(range => range.count > 0);
        }

        async function analyzeEvents() {
            const resultsDiv = document.getElementById('results');
            const resultsContent = document.getElementById('results-content');
            
            resultsDiv.style.display = 'block';
            resultsContent.innerHTML = '<div class="loading">🔄 Analyzing your academic workload...</div>';
            resultsDiv.scrollIntoView({ behavior: 'smooth' });
            
            try {
                const response = await fetch('/api/highest-weight-event?user_id=student123');
                const data = await response.json();
                
                let html = '';
                
                if (data.success && data.data.event) {
                    const event = data.data.event;
                    const analysis = data.data.analysis;
                    
                    const urgencyClass = analysis.urgency_level;
                    
                    html += `
                        <div style="background: linear-gradient(45deg, #50E3C2, #122C4A); color: white; padding: 25px; border-radius: 12px; margin-bottom: 25px;">
                            <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;">
                                <div>
                                    <h4 style="margin: 0 0 10px 0;">🎯 Highest Priority Event</h4>
                                    <h2 style="margin: 0 0 10px 0;">${event.title}</h2>
                                    <p style="margin: 0;"><strong>Course:</strong> ${event.course_name}</p>
                                    <p style="margin: 5px 0 0 0;"><strong>Type:</strong> ${event.type.charAt(0).toUpperCase() + event.type.slice(1)}</p>
                                </div>
                                <span class="priority-badge ${urgencyClass}">${analysis.urgency_level.toUpperCase()}</span>
                            </div>
                            <p><strong>Due:</strong> ${new Date(event.due_date).toLocaleDateString()} (${event.days_until_due} days)</p>
                        </div>
                        
                        <div class="metrics">
                            <div class="metric">
                                <div class="metric-value">${Math.round(event.weight * 100)}%</div>
                                <div class="metric-label">Grade Weight</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value">${event.days_until_due}</div>
                                <div class="metric-label">Days Until Due</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value">${event.priority_score}</div>
                                <div class="metric-label">Priority Score</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value">${analysis.total_pending_events}</div>
                                <div class="metric-label">Total Pending</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value">${analysis.course_load}</div>
                                <div class="metric-label">Course Load</div>
                            </div>
                        </div>
                    `;
                    
                    if (data.data.recommendations && data.data.recommendations.length > 0) {
                        html += '<h4 style="margin: 30px 0 15px 0;">💡 Personalized Recommendations</h4><ul style="list-style: none; padding: 0;">';
                        data.data.recommendations.forEach((rec, index) => {
                            html += `<li style="margin: 12px 0; padding: 15px; background: #f8f9fa; border-radius: 8px; border-left: 4px solid #50E3C2;">
                                <strong>${index + 1}.</strong> ${rec}
                            </li>`;
                        });
                        html += '</ul>';
                    }
                } else {
                    html = `
                        <div style="background: #4ECDC4; color: white; padding: 25px; border-radius: 12px; text-align: center;">
                            <h4 style="margin: 0 0 10px 0;">🎉 All Caught Up!</h4>
                            <p style="margin: 0;">${data.message}</p>
                        </div>
                    `;
                }
                
                html += `
                    <details style="margin-top: 30px;">
                        <summary style="cursor: pointer; font-weight: bold; color: #122C4A;">📋 Raw API Response</summary>
                        <pre style="margin-top: 15px;">${JSON.stringify(data, null, 2)}</pre>
                    </details>
                `;
                resultsContent.innerHTML = html;
                
            } catch (error) {
                resultsContent.innerHTML = `<div style="color: red; padding: 20px; background: #ffebee; border-radius: 8px;">Error: ${error.message}</div>`;
            }
        }
        
        async function loadStudentData() {
            const resultsDiv = document.getElementById('results');
            const resultsContent = document.getElementById('results-content');
            
            resultsDiv.style.display = 'block';
            resultsContent.innerHTML = '<div class="loading">📚 Loading your academic data...</div>';
            resultsDiv.scrollIntoView({ behavior: 'smooth' });
            
            try {
                const response = await fetch('/api/student-data?user_id=student123');
                const data = await response.json();
                
                let html = `
                    <h4>📊 Your Academic Profile</h4>
                    <div class="metrics">
                        <div class="metric">
                            <div class="metric-value">${data.courses.length}</div>
                            <div class="metric-label">Courses</div>
                        </div>
                        <div class="metric">
                            <div class="metric-value">${data.events.length}</div>
                            <div class="metric-label">Total Events</div>
                        </div>
                        <div class="metric">
                            <div class="metric-value">${data.events.filter(e => e.status === 'pending').length}</div>
                            <div class="metric-label">Pending</div>
                        </div>
                        <div class="metric">
                            <div class="metric-value">${data.events.filter(e => e.status === 'completed').length}</div>
                            <div class="metric-label">Completed</div>
                        </div>
                    </div>
                    
                    <details style="margin-top: 25px;">
                        <summary style="cursor: pointer; font-weight: bold; color: #122C4A;">📋 Raw Academic Data</summary>
                        <pre style="margin-top: 15px;">${JSON.stringify(data, null, 2)}</pre>
                    </details>
                `;
                
                resultsContent.innerHTML = html;
                
            } catch (error) {
                resultsContent.innerHTML = `<div style="color: red; padding: 20px; background: #ffebee; border-radius: 8px;">Error: ${error.message}</div>`;
            }
        }

        // Auto-load charts when page loads
        window.addEventListener('load', function() {
            setTimeout(loadCharts, 1000);
        });
    </script>
</body>
</html>
        """
        
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self._set_cors_headers()
        self.end_headers()
        self.wfile.write(html_content.encode())
    
    def log_message(self, format, *args):
        """Custom log format"""
        print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {format % args}")

def run_server(port=8080):
    """Start the analytics server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, AnalyticsHandler)
    
    print(f"""
🎯 AceUp Analytics Server Started!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Business Question 2.1: Highest Weight Pending Event Analysis
🌐 Dashboard: http://localhost:{port}
🔗 API Endpoints:
   • Health Check: http://localhost:{port}/api/health
   • BQ Analysis:  http://localhost:{port}/api/highest-weight-event
   • Student Data: http://localhost:{port}/api/student-data

🚀 Server ready for analytics requests...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """)
    
    # Auto-open browser after a short delay
    def open_browser():
        time.sleep(1)
        webbrowser.open(f'http://localhost:{port}')
    
    threading.Thread(target=open_browser, daemon=True).start()
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
        httpd.server_close()

if __name__ == '__main__':
    run_server()