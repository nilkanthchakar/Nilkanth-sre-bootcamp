package com.example.studentapi.controller;

import com.example.studentapi.exception.ApiExceptionHandler;
import com.example.studentapi.model.Student;
import com.example.studentapi.service.StudentService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class StudentControllerTest {

    private MockMvc mockMvc;
    private StubStudentService studentService;

    @BeforeEach
    void setUp() {
        studentService = new StubStudentService();
        mockMvc = MockMvcBuilders.standaloneSetup(new StudentController(studentService))
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void getAllStudentsShouldReturnListOfStudents() throws Exception {
        Student student = createStudent(1L, "John", "Doe", "john@example.com");
        studentService.students.add(student);

        mockMvc.perform(get("/api/v1/students"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].firstName").value("John"))
                .andExpect(jsonPath("$[0].email").value("john@example.com"));
    }

    @Test
    void createStudentShouldReturnCreatedStudent() throws Exception {
        mockMvc.perform(post("/api/v1/students")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"Jane\",\"lastName\":\"Smith\",\"email\":\"jane@example.com\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.firstName").value("Jane"));
    }

    @Test
    void createStudentWithInvalidPayloadShouldFailValidation() throws Exception {
        mockMvc.perform(post("/api/v1/students")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"\",\"lastName\":\"\",\"email\":\"not-an-email\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void updateStudentShouldReturnUpdatedStudent() throws Exception {
        mockMvc.perform(put("/api/v1/students/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"Updated\",\"lastName\":\"Name\",\"email\":\"updated@example.com\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.firstName").value("Updated"));
    }

    @Test
    void deleteStudentShouldReturnNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/students/1"))
                .andExpect(status().isNoContent());
    }

    private static Student createStudent(Long id, String firstName, String lastName, String email) {
        Student student = new Student();
        student.setId(id);
        student.setFirstName(firstName);
        student.setLastName(lastName);
        student.setEmail(email);
        student.setEnrolledAt(LocalDateTime.of(2024, 1, 1, 10, 0));
        return student;
    }

    private static class StubStudentService extends StudentService {
        private final List<Student> students = new ArrayList<>();
        private final Map<Long, Student> studentById = new LinkedHashMap<>();

        private StubStudentService() {
            super(null);
        }

        @Override
        public List<Student> getAllStudents() {
            return students;
        }

        @Override
        public Student createStudent(Student student) {
            student.setId((long) (students.size() + 1));
            student.setEnrolledAt(LocalDateTime.now());
            students.add(student);
            studentById.put(student.getId(), student);
            return student;
        }

        @Override
        public Student getStudentById(Long id) {
            Student student = studentById.get(id);
            if (student == null) {
                throw new IllegalArgumentException("Student not found with id " + id);
            }
            return student;
        }

        @Override
        public Student updateStudent(Long id, Student student) {
            Student existing = studentById.get(id);
            if (existing == null) {
                existing = StudentControllerTest.createStudent(id, student.getFirstName(), student.getLastName(), student.getEmail());
                studentById.put(id, existing);
                students.add(existing);
            } else {
                existing.setFirstName(student.getFirstName());
                existing.setLastName(student.getLastName());
                existing.setEmail(student.getEmail());
                studentById.put(id, existing);
            }
            return existing;
        }

        @Override
        public void deleteStudent(Long id) {
            studentById.remove(id);
            students.removeIf(student -> student.getId() != null && student.getId().equals(id));
        }
    }
}
