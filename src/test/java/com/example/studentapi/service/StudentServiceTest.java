package com.example.studentapi.service;

import com.example.studentapi.exception.ResourceNotFoundException;
import com.example.studentapi.model.Student;
import com.example.studentapi.repository.StudentRepository;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Proxy;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class StudentServiceTest {

    private final StudentService studentService = new StudentService(createRepositoryStub());

    @Test
    void createStudentShouldSetEnrolledAtAndSaveStudent() {
        Student input = createStudent(null, "John", "Doe", "john@example.com");

        Student result = studentService.createStudent(input);

        assertNotNull(result.getEnrolledAt());
        assertEquals("John", result.getFirstName());
    }

    @Test
    void getAllStudentsShouldReturnAllStudentsFromRepository() {
        Student first = createStudent(1L, "John", "Doe", "john@example.com");
        Student second = createStudent(2L, "Jane", "Smith", "jane@example.com");
        StudentRepository repository = createRepositoryStub();
        repository.save(first);
        repository.save(second);
        StudentService service = new StudentService(repository);

        List<Student> result = service.getAllStudents();

        assertEquals(2, result.size());
        assertEquals(first, result.get(0));
        assertEquals(second, result.get(1));
    }

    @Test
    void getStudentByIdShouldThrowExceptionWhenStudentIsMissing() {
        ResourceNotFoundException exception = assertThrows(
                ResourceNotFoundException.class,
                () -> studentService.getStudentById(99L)
        );

        assertTrue(exception.getMessage().contains("99"));
    }

    @Test
    void updateStudentShouldUpdateExistingStudentFields() {
        Student existing = createStudent(1L, "Old", "Name", "old@example.com");
        Student updates = createStudent(null, "New", "Name", "new@example.com");
        StudentRepository repository = createRepositoryStub();
        repository.save(existing);
        StudentService service = new StudentService(repository);

        Student result = service.updateStudent(1L, updates);

        assertEquals("New", result.getFirstName());
        assertEquals("Name", result.getLastName());
        assertEquals("new@example.com", result.getEmail());
    }

    @Test
    void deleteStudentShouldDeleteExistingStudent() {
        Student existing = createStudent(1L, "John", "Doe", "john@example.com");
        StudentRepository repository = createRepositoryStub();
        repository.save(existing);
        StudentService service = new StudentService(repository);

        service.deleteStudent(1L);

        assertThrows(ResourceNotFoundException.class, () -> service.getStudentById(1L));
    }

    private StudentRepository createRepositoryStub() {
        final Map<Long, Student> storage = new HashMap<>();
        final List<Student> students = new ArrayList<>();
        final long[] nextId = {1L};

        return (StudentRepository) Proxy.newProxyInstance(
                StudentRepository.class.getClassLoader(),
                new Class[]{StudentRepository.class},
                (proxy, method, args) -> {
                    String methodName = method.getName();
                    if ("save".equals(methodName)) {
                        Student student = (Student) args[0];
                        if (student.getId() == null) {
                            student.setId(nextId[0]++);
                        }
                        storage.put(student.getId(), student);
                        students.clear();
                        students.addAll(storage.values());
                        return student;
                    }
                    if ("findAll".equals(methodName)) {
                        return new ArrayList<>(students);
                    }
                    if ("findById".equals(methodName)) {
                        Long id = (Long) args[0];
                        return Optional.ofNullable(storage.get(id));
                    }
                    if ("delete".equals(methodName)) {
                        Student student = (Student) args[0];
                        storage.remove(student.getId());
                        students.clear();
                        students.addAll(storage.values());
                        return null;
                    }
                    if ("deleteById".equals(methodName)) {
                        Long id = (Long) args[0];
                        storage.remove(id);
                        students.clear();
                        students.addAll(storage.values());
                        return null;
                    }
                    if ("existsById".equals(methodName)) {
                        Long id = (Long) args[0];
                        return storage.containsKey(id);
                    }
                    if ("count".equals(methodName)) {
                        return (long) storage.size();
                    }
                    return null;
                }
        );
    }

    private Student createStudent(Long id, String firstName, String lastName, String email) {
        Student student = new Student();
        student.setId(id);
        student.setFirstName(firstName);
        student.setLastName(lastName);
        student.setEmail(email);
        student.setEnrolledAt(LocalDateTime.of(2024, 1, 1, 10, 0));
        return student;
    }
}
