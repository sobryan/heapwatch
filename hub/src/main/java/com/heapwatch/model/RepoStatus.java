package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * Status of a connected source code repository.
 */
@Data
@Builder
public class RepoStatus {
    private String repoUrl;
    private String branch;
    private String localPath;
    private boolean connected;
    private int indexedFiles;
    private int indexedClasses;
    private String lastIndexed;
    private String error;
}
